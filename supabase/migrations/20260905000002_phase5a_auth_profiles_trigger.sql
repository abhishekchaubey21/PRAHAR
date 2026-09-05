-- ============================================================================
-- PRAHAR Phase 5A — Supabase Auth User Synchronization & Secure Role Enforcement
-- Aligned with Phase 5A Amendment 2:
-- - Public registration strictly defaults to FARMER
-- - Client-supplied role claims are ignored
-- - Role elevation to EXPERT or ADMIN requires privileged admin action
-- ============================================================================

-- 1. Secure Trigger: Synchronizes new auth.users into public.profiles with safe default 'FARMER'
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Safe default: Ignore any client-supplied role in metadata; always create FARMER
  INSERT INTO public.profiles (id, email, full_name, role, farmer_id)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', SPLIT_PART(NEW.email, '@', 1)),
    'FARMER', -- Enforced default
    CASE 
      WHEN (NEW.raw_user_meta_data->>'farmer_id') IS NOT NULL 
      THEN (NEW.raw_user_meta_data->>'farmer_id')::UUID 
      ELSE NULL 
    END
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name),
      updated_at = NOW();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Drop trigger if already exists and recreate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Privileged Function: Promote user role (Admin / Service-Role only)
CREATE OR REPLACE FUNCTION public.promote_user_role(target_user_id UUID, new_role TEXT)
RETURNS VOID AS $$
BEGIN
  -- Verify caller is ADMIN or service_role
  IF public.get_user_role() != 'ADMIN' AND auth.role() != 'service_role' THEN
    RAISE EXCEPTION 'Access Denied: Only ADMIN or service_role can promote user roles.';
  END IF;

  IF new_role NOT IN ('FARMER', 'EXPERT', 'ADMIN') THEN
    RAISE EXCEPTION 'Invalid role: Must be FARMER, EXPERT, or ADMIN.';
  END IF;

  UPDATE public.profiles
  SET role = new_role,
      updated_at = NOW()
  WHERE id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Revoke public execution on sensitive role elevation function
REVOKE ALL ON FUNCTION public.promote_user_role(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.promote_user_role(UUID, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.promote_user_role(UUID, TEXT) TO authenticated, service_role;
