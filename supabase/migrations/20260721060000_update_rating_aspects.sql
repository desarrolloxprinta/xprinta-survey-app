ALTER TABLE projects 
  ADD COLUMN IF NOT EXISTS rating_puntualidad INTEGER CHECK (rating_puntualidad >= 1 AND rating_puntualidad <= 5),
  ADD COLUMN IF NOT EXISTS rating_calidad INTEGER CHECK (rating_calidad >= 1 AND rating_calidad <= 5),
  ADD COLUMN IF NOT EXISTS rating_limpieza INTEGER CHECK (rating_limpieza >= 1 AND rating_limpieza <= 5);
