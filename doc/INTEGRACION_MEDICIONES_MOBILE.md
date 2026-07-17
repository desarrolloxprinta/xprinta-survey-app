# Integración: Sistema de Mediciones - App Móvil → Web App

## 📋 Resumen

Este documento contiene el **prompt exacto** para integrar el formulario de mediciones de la app móvil con el sistema web de Xprinta.

---

## 🎯 Prompt para Agente de App Móvil

```
# TAREA: Integrar formulario de mediciones con API de Xprinta Web

## Contexto
Necesitas enviar los datos del formulario de medición completado en la app móvil a la API de Xprinta Web para que se cree una ficha de medición vinculada a un proyecto.

## Endpoint de API
**URL**: `https://tudominio.com/api/mediciones/create`
**Método**: `POST`
**Autenticación**: Bearer token (JWT del usuario autenticado)

## Estructura de Datos Requerida

```typescript
interface CreateMedicionRequest {
  // ✅ OBLIGATORIO
  project_id: string;           // UUID del proyecto al que pertenece
  nombre: string;               // Ej: "Medicion rotulo", "Medicion banderola"

  // ⚙️ RECOMENDADO
  tipo_elemento?: string;       // Ej: "Rótulo", "Banderola", "Vinilo de cristal"
  status?: 'pendiente' | 'en_progreso' | 'completada' | 'revisión_requerida';

  // 📊 Datos del formulario (flexible - todos los campos van aquí)
  measurement_data?: {
    [key: string]: any;         // Cualquier campo del formulario
    // Ejemplos:
    // ancho?: number;
    // alto?: number;
    // material?: string;
    // color?: string;
    // notas_tecnicas?: string;
    // etc.
  };

  // 📸 Archivos (URLs o paths de fotos)
  attached_files?: string[];    // Array de URLs de fotos tomadas

  // 📍 Geolocalización (opcional)
  latitude?: number;            // -90 a 90
  longitude?: number;           // -180 a 180

  // 👤 Asignación
  measured_by?: string;         // UUID del técnico (tu usuario)

  // 📅 Fechas
  scheduled_date?: string;      // ISO 8601: "2026-07-16"
  measurement_date?: string;    // ISO 8601: "2026-07-16T10:30:00Z"

  // 📝 Notas
  notas?: string;               // Notas visibles para cliente
  internal_notes?: string;      // Notas internas Xprinta
}
```

## Ejemplo de Request Completo

```json
POST /api/mediciones/create
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

{
  "project_id": "550e8400-e29b-41d4-a716-446655440000",
  "nombre": "Medicion rotulo principal",
  "tipo_elemento": "Rótulo luminoso",
  "status": "completada",
  "measurement_data": {
    "ancho_cm": 250,
    "alto_cm": 80,
    "profundidad_cm": 15,
    "material": "Aluminio dibond",
    "iluminacion": "LED interior",
    "color_corporativo": "#FA8029",
    "instalacion_tipo": "Fachada",
    "acceso_dificultad": "Media",
    "notas_tecnicas": "Requiere anclajes especiales por estructura antigua"
  },
  "attached_files": [
    "https://storage.supabase.co/mediciones/foto1.jpg",
    "https://storage.supabase.co/mediciones/foto2.jpg",
    "https://storage.supabase.co/mediciones/foto3.jpg"
  ],
  "latitude": 40.416775,
  "longitude": -3.703790,
  "measured_by": "user-uuid-del-tecnico",
  "measurement_date": "2026-07-16T10:30:00Z",
  "notas": "Cliente solicita instalación urgente antes de fin de mes",
  "internal_notes": "Coordinar con equipo de fabricación para priorizar"
}
```

## Flujo de Integración Paso a Paso

1. **Completar formulario en app móvil**
   - Usuario técnico rellena campos
   - Toma fotos del elemento/ubicación
   - Captura geolocalización

2. **Subir fotos a storage** (si usas Supabase)
   ```typescript
   const uploadPhotos = async (files: File[]) => {
     const urls = [];
     for (const file of files) {
       const { data } = await supabase.storage
         .from('user-documents')
         .upload(`mediciones/${Date.now()}_${file.name}`, file);

       const { data: signedUrl } = await supabase.storage
         .from('user-documents')
         .createSignedUrl(data.path, 31536000); // 1 año

       urls.push(signedUrl.signedUrl);
     }
     return urls;
   };
   ```

3. **Construir objeto de medición**
   ```typescript
   const medicionData = {
     project_id: projectIdActual,
     nombre: formulario.nombreMedicion,
     tipo_elemento: formulario.tipoElemento,
     status: 'completada',
     measurement_data: {
       ...formulario.todasLasMedidas
     },
     attached_files: fotosUrls,
     latitude: geolocalizacion.lat,
     longitude: geolocalizacion.lng,
     measured_by: usuarioActual.id,
     measurement_date: new Date().toISOString(),
     notas: formulario.notasGenerales
   };
   ```

4. **Enviar a API**
   ```typescript
   const response = await fetch('https://tudominio.com/api/mediciones/create', {
     method: 'POST',
     headers: {
       'Content-Type': 'application/json',
       'Authorization': `Bearer ${userToken}`
     },
     body: JSON.stringify(medicionData)
   });

   if (response.ok) {
     const result = await response.json();
     console.log('✅ Medición creada:', result.data.id);
     // Mostrar confirmación al usuario
   }
   ```

## Validaciones Importantes

### ✅ Campos Obligatorios
- `project_id`: Debe existir en base de datos
- `nombre`: Mínimo 3 caracteres

### ⚠️ Validaciones Recomendadas
- `status`: Solo valores permitidos: pendiente | en_progreso | completada | revisión_requerida
- `latitude`: Entre -90 y 90
- `longitude`: Entre -180 y 180
- `attached_files`: URLs válidas y accesibles

### 🔒 Seguridad
- **Autenticación**: Requiere JWT token válido
- **Permisos RLS**: Solo técnicos y xprinta users pueden crear mediciones
- El `measured_by` se valida contra el usuario autenticado

## Respuesta de la API

### Éxito (200 OK)
```json
{
  "data": {
    "id": "medicion-uuid-generado",
    "project_id": "550e8400-e29b-41d4-a716-446655440000",
    "nombre": "Medicion rotulo principal",
    "status": "completada",
    "created_at": "2026-07-16T10:35:22Z"
  },
  "error": null
}
```

### Error (400 Bad Request)
```json
{
  "data": null,
  "error": "project_id es obligatorio"
}
```

### Error (401 Unauthorized)
```json
{
  "error": "Usuario no autenticado"
}
```

## Testing

### Caso de Prueba 1: Medición Básica
```json
{
  "project_id": "tu-project-id-de-prueba",
  "nombre": "Test Medicion Rotulo",
  "tipo_elemento": "Rótulo",
  "status": "pendiente",
  "measurement_data": {
    "ancho": 100,
    "alto": 50
  }
}
```

### Caso de Prueba 2: Medición Completa
Ver ejemplo completo arriba en "Ejemplo de Request Completo"

## Arquitectura Backend (para referencia)

```
App Móvil
    ↓ POST /api/mediciones/create
API Route (Next.js)
    ↓ Validación + Autenticación
medicionesService.createMedicion()
    ↓ RLS Policies
Supabase: tabla mediciones
    ↓ Trigger update_mediciones_updated_at
Base de Datos PostgreSQL
```

## Vista en Web App

Una vez creada la medición, estará disponible en:

1. **Directorio de Mediciones**: `/mediciones`
   - Listado de todas las mediciones
   - Filtros por estado
   - Búsqueda por proyecto

2. **Detalle de Medición**: `/mediciones/{id}`
   - Información completa
   - Datos del formulario
   - Fotos adjuntas
   - Proyecto asociado

3. **Vista de Proyecto**: `/proyectos/{id}`
   - Tab "Mediciones" con todas las mediciones del proyecto

## Notas Adicionales

- **Flexibilidad**: `measurement_data` es JSONB, acepta cualquier estructura
- **Versionado**: Si cambias la estructura del formulario, todo se guarda automáticamente
- **Sin Esquema Rígido**: No necesitas modificar base de datos al agregar campos nuevos
- **Relación 1:N**: Un proyecto puede tener múltiples mediciones

## Soporte

Si necesitas ayuda con la integración, contacta al equipo backend con:
- El payload exacto que estás enviando
- El error específico que recibes
- Los logs de la app móvil
```

---

## 📦 Archivos Creados en Web App

### Migración de Base de Datos
```
supabase/migrations/20260716000001_create_mediciones_table.sql
```

### Servicio
```
src/services/medicionesService.ts
```

### Páginas
```
src/pages/MedicionesPage.tsx          - Directorio de mediciones
src/pages/MedicionesPage.css
src/pages/MedicionDetailPage.tsx      - Detalle de medición
src/pages/MedicionDetailPage.css
```

### Rutas y Navegación
- Sidebar actualizado para mostrar "Mediciones" a técnicos y punto-xprinta
- Routes agregados en App.tsx

---

## ⚡ Siguientes Pasos

1. **Ejecutar migración en tu base de datos**:
   ```bash
   # Opción 1: Via psql
   psql "postgresql://user:pass@host:port/db" -f supabase/migrations/20260716000001_create_mediciones_table.sql

   # Opción 2: Via Supabase CLI
   supabase db push
   ```

2. **Crear API endpoint** (si no existe):
   ```typescript
   // pages/api/mediciones/create.ts
   import { createMedicion } from '@/services/medicionesService';

   export default async function handler(req, res) {
     if (req.method !== 'POST') {
       return res.status(405).json({ error: 'Method not allowed' });
     }

     const { data, error } = await createMedicion(req.body);

     if (error) {
       return res.status(400).json({ data: null, error });
     }

     return res.status(200).json({ data, error: null });
   }
   ```

3. **Compartir este documento con el agente de app móvil**

---

**Fecha de creación**: 2026-07-16
**Sistema**: Xprinta Web - Mediciones
**Versión**: 1.0
