-- Migration: Add instalaciones table and installation tracking columns to projects

-- 1. Create instalaciones table if not exists
CREATE TABLE IF NOT EXISTS instalaciones (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  status TEXT DEFAULT 'completada',
  installation_data JSONB DEFAULT '{}'::jsonb,
  attached_files TEXT[] DEFAULT ARRAY[]::TEXT[],
  installed_by UUID REFERENCES auth.users(id),
  installation_date TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookup by project_id
CREATE INDEX IF NOT EXISTS idx_instalaciones_project_id ON instalaciones(project_id);

-- 2. Add installation tracking columns to projects table
ALTER TABLE projects 
  ADD COLUMN IF NOT EXISTS installation_phase TEXT DEFAULT 'desconocido',
  ADD COLUMN IF NOT EXISTS installation_assigned_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS scheduled_installation_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS installation_completed_date TIMESTAMPTZ;
