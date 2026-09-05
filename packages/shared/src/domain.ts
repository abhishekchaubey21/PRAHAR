/**
 * PRAHAR — Core Agricultural Entities (Section 9)
 */

export interface Farmer {
  id: string;
  name: string;
  phone: string;
  language: string;
  created_at: string;
}

export interface Farm {
  id: string;
  farmer_id: string;
  name: string;
  boundary_geojson: Record<string, any>;
  crop_type: string;
  area_acres: number;
  created_at: string;
}

export interface Zone {
  id: string;
  farm_id: string;
  zone_name: string;
  geometry_geojson: Record<string, any>;
  soil_type: string;
  last_scan_at?: string;
  created_at: string;
}
