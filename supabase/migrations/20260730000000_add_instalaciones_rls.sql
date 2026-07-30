-- Enable RLS for instalaciones
ALTER TABLE instalaciones ENABLE ROW LEVEL SECURITY;

-- Grant access to PostgREST roles
GRANT SELECT, INSERT, UPDATE, DELETE ON instalaciones TO anon, authenticated;

-- Add RLS Policies for instalaciones
CREATE POLICY "Allow all select on instalaciones" ON instalaciones FOR SELECT TO public USING (true);
CREATE POLICY "Allow all insert on instalaciones" ON instalaciones FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow all update on instalaciones" ON instalaciones FOR UPDATE TO public USING (true);
CREATE POLICY "Allow all delete on instalaciones" ON instalaciones FOR DELETE TO public USING (true);
