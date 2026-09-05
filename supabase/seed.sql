-- ============================================================================
-- PRAHAR Engineering Foundation — Synthetic Demo Seed Data
-- Uses only clearly synthetic/demo data per safety constraints.
-- ============================================================================

-- 1. Demo Farmer
INSERT INTO public.farmers (id, name, phone, language)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'Demo Farmer Alpha',
    '+91-00000-00001',
    'hi'
) ON CONFLICT (id) DO NOTHING;

-- 2. Demo Farm
INSERT INTO public.farms (id, farmer_id, name, crop_type, area_acres, boundary_geojson)
VALUES (
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    'Demo Precision Field Alpha',
    'Tomato (Solanum lycopersicum)',
    3.5,
    '{"type": "Polygon", "coordinates": [[[77.5901, 12.9701], [77.5945, 12.9701], [77.5945, 12.9745], [77.5901, 12.9745], [77.5901, 12.9701]]]}'::jsonb
) ON CONFLICT (id) DO NOTHING;

-- 3. Demo Zones (Atomic Spatial Units)
INSERT INTO public.zones (id, farm_id, zone_name, soil_type, geometry_geojson)
VALUES 
    (
        'DEMO-ZONE-01',
        '00000000-0000-0000-0000-000000000002',
        'Zone 1 - North Sector',
        'Clay Loam',
        '{"type": "Polygon", "coordinates": [[[77.5901, 12.9723], [77.5923, 12.9723], [77.5923, 12.9745], [77.5901, 12.9745], [77.5901, 12.9723]]]}'::jsonb
    ),
    (
        'DEMO-ZONE-02',
        '00000000-0000-0000-0000-000000000002',
        'Zone 2 - East Sector',
        'Sandy Loam',
        '{"type": "Polygon", "coordinates": [[[77.5923, 12.9723], [77.5945, 12.9723], [77.5945, 12.9745], [77.5923, 12.9745], [77.5923, 12.9723]]]}'::jsonb
    ),
    (
        'DEMO-ZONE-03',
        '00000000-0000-0000-0000-000000000002',
        'Zone 3 - South Sector',
        'Silt Loam',
        '{"type": "Polygon", "coordinates": [[[77.5923, 12.9701], [77.5945, 12.9701], [77.5945, 12.9723], [77.5923, 12.9723], [77.5923, 12.9701]]]}'::jsonb
    ),
    (
        'DEMO-ZONE-04',
        '00000000-0000-0000-0000-000000000002',
        'Zone 4 - West Sector',
        'Clay',
        '{"type": "Polygon", "coordinates": [[[77.5901, 12.9701], [77.5923, 12.9701], [77.5923, 12.9723], [77.5901, 12.9723], [77.5901, 12.9701]]]}'::jsonb
    )
ON CONFLICT (id) DO NOTHING;

-- 4. Initial Synthetic Sensor Readings
INSERT INTO public.sensor_readings (zone_id, type, value, unit, source)
VALUES
    ('DEMO-ZONE-01', 'moisture', 38.5, '%', 'rover_probe_demo'),
    ('DEMO-ZONE-01', 'temperature', 28.2, '°C', 'rover_ambient_demo'),
    ('DEMO-ZONE-01', 'humidity', 65.0, '%', 'rover_ambient_demo'),
    ('DEMO-ZONE-01', 'ph', 6.8, 'pH', 'rover_probe_demo'),
    ('DEMO-ZONE-02', 'moisture', 18.4, '%', 'rover_probe_demo'), -- Low moisture (Water Stress)
    ('DEMO-ZONE-02', 'temperature', 34.1, '°C', 'rover_ambient_demo'),
    ('DEMO-ZONE-02', 'humidity', 42.0, '%', 'rover_ambient_demo'),
    ('DEMO-ZONE-02', 'ph', 6.5, 'pH', 'rover_probe_demo'),
    ('DEMO-ZONE-03', 'moisture', 31.0, '%', 'rover_probe_demo'),
    ('DEMO-ZONE-03', 'temperature', 29.5, '°C', 'rover_ambient_demo'),
    ('DEMO-ZONE-03', 'humidity', 72.0, '%', 'rover_ambient_demo'),
    ('DEMO-ZONE-03', 'ph', 6.2, 'pH', 'rover_probe_demo');

-- 5. Initial Synthetic Detections
INSERT INTO public.detections (zone_id, hazard_type, hazard_name, confidence, severity_hint, notes)
VALUES
    ('DEMO-ZONE-02', 'WATER_STRESS', 'Severe Soil Moisture Depletion', 0.92, 'HIGH', 'Simulated low root-zone moisture below threshold'),
    ('DEMO-ZONE-03', 'DISEASE', 'Early Blight (Alternaria solani)', 0.86, 'MEDIUM', 'Simulated concentric ring lesions detected on lower leaves');

-- 6. Initial Synthetic Alerts
INSERT INTO public.alerts (zone_id, type, severity, status, message, recommended_action)
VALUES
    ('DEMO-ZONE-02', 'WATER_STRESS', 'HIGH', 'NEW', 'Zone 2 moisture level dropped to 18.4%. Immediate micro-irrigation advised.', 'Trigger targeted irrigation for Zone 2 (45 seconds)'),
    ('DEMO-ZONE-03', 'DISEASE', 'MEDIUM', 'NEW', 'Zone 3 shows suspected Early Blight symptoms (86% confidence).', 'Expert triage review pending. Isolate affected plot.');
