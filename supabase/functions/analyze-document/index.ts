import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const validityRules: Record<string, any> = {
  "reconocimiento_medico": {
    "names": ["reconocimiento médico", "certificado médico", "aptitud médica", "examen médico", "revisión médica", "apto para el trabajo"],
    "validity_months": 12,
    "reason": "Los reconocimientos médicos tienen validez de 1 año según normativa PRL"
  },
  "certificado_formacion_altura": {
    "names": ["trabajos en altura", "trabajo en altura", "formación en altura", "curso de altura"],
    "validity_months": 36,
    "reason": "Certificados de trabajos en altura tienen validez de 3 años"
  },
  "certificado_formacion_plataformas": {
    "names": ["plataforma elevadora", "plataformas elevadoras", "pemp", "manipulador de cargas"],
    "validity_months": 60,
    "reason": "Certificados de plataformas elevadoras tienen validez de 5 años"
  },
  "certificado_formacion_prl": {
    "names": ["prevención de riesgos laborales", "prl 60 horas", "curso prl", "formación prl", "prevención riesgos"],
    "validity_months": 36,
    "reason": "Formación PRL tiene validez de 3 años"
  },
  "certificado_instalador_rotulos": {
    "names": ["instalador de rótulos", "instalación de rótulos", "rótulos luminosos", "instalador rotulista"],
    "validity_months": 36,
    "reason": "Certificados de instalador de rótulos suelen tener validez de 3 años"
  },
  "certificado_instalaciones_electricas": {
    "names": ["instalaciones eléctricas", "baja tensión", "alta tensión", "electricista", "instalador eléctrico", "habilitación eléctrica"],
    "validity_months": 60,
    "reason": "Certificados de instalaciones eléctricas tienen validez de 5 años"
  },
  "certificado_carretillas_elevadoras": {
    "names": ["carretilla elevadora", "carretillas elevadoras", "operador de carretillas", "manipulación de carretillas"],
    "validity_months": 60,
    "reason": "Certificados de carretillas elevadoras tienen validez de 5 años"
  },
  "certificado_extincion_incendios": {
    "names": ["extinción de incendios", "extintor", "lucha contra incendios", "prevención de incendios", "emergencias", "protección contra incendios"],
    "validity_months": 12,
    "reason": "Certificados de extinción de incendios se renuevan anualmente"
  },
  "certificado_recursos_preventivos": {
    "names": ["recurso preventivo", "recursos preventivos", "designación recurso preventivo", "formación recurso preventivo"],
    "validity_months": 36,
    "reason": "Certificados de recursos preventivos tienen validez de 3 años"
  },
  "seguro_rc": {
    "names": ["seguro de responsabilidad civil", "seguro rc", "póliza rc", "responsabilidad civil", "seguro profesional"],
    "validity_months": 12,
    "reason": "Los seguros RC se renuevan anualmente"
  },
  "certificado_ss_aeat": {
    "names": ["certificado aeat", "hacienda", "agencia tributaria", "seguridad social", "corriente de pago", "estar al corriente"],
    "validity_months": 6,
    "reason": "Certificados de AEAT y SS tienen validez de 6 meses"
  }
};

function calculateExpiryDate(issueDate: string, months: number): string {
  const [year, month, day] = issueDate.split('-').map(Number);
  const d = new Date(Date.UTC(year, month - 1 + months, day));
  return d.toISOString().split('T')[0];
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { imageBase64, mimeType, documentType } = await req.json()
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')

    if (!geminiApiKey) throw new Error('GEMINI_API_KEY no está configurado.');
    if (!imageBase64) throw new Error('No imagen proporcionada.');

    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiApiKey}`

    const systemPrompt = `Eres un experto en análisis de documentos españoles. Analiza esta imagen y extrae fechas.

TIPO DE DOCUMENTO INDICADO POR USUARIO: ${documentType || 'Desconocido'}

OBJETIVO:
Encuentra DOS fechas clave (si están disponibles en el documento):
1. Fecha de EMISIÓN/INICIO/EXPEDICIÓN (cuando se emitió o inició validez)
2. Fecha de CADUCIDAD/VENCIMIENTO/FIN (cuando expira o termina validez)

⚠️ IMPORTANTE:
- Busca PRIMERO si existe una fecha de caducidad EXPLÍCITA en el documento.
- NO inventes fechas de caducidad. Si el documento NO indica que caduca, pon expiry_date null. Nosotros calcularemos su caducidad según la ley.
- Si ves un formato corto de año como '01 01 32', asume SIEMPRE el siglo 21 (2032-01-01).

REGLAS ESPECÍFICAS DE BÚSQUEDA SEGÚN EL DOCUMENTO:
1. DNIs y Pasaportes: La caducidad suele estar en el ANVERSO bajo 'VALIDEZ'. La emisión bajo 'FECHA DE EMISIÓN'. 
2. Certificados de la Seguridad Social o Hacienda: Busca "Validez de X meses" o "Válido hasta".
3. PRL, Cursos, Trabajos en Altura: Busca "Fecha de caducidad", "Próximo reciclaje".
4. Seguros RC: "Póliza vigencia desde... hasta...".

Extrae las fechas al formato estricto YYYY-MM-DD.
En 'reasoning', escribe un párrafo pensando paso a paso qué fechas ves y por qué. Incluye también palabras clave del documento que te ayuden a saber de qué tipo de curso/documento se trata.`;

    const payload = {
      contents: [{
        parts: [
          { text: systemPrompt },
          { inlineData: { mimeType: mimeType || 'image/jpeg', data: imageBase64 } }
        ]
      }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "OBJECT",
          properties: {
            issue_date: { type: "STRING", description: "Fecha emisión YYYY-MM-DD", nullable: true },
            expiry_date: { type: "STRING", description: "Fecha caducidad YYYY-MM-DD", nullable: true },
            reasoning: { type: "STRING", description: "Tu razonamiento" }
          },
          required: ["reasoning"]
        }
      }
    }

    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    const result = await response.json();
    if (result.error) throw new Error(result.error.message);

    const content = result.candidates[0].content.parts[0].text;
    const parsedData = JSON.parse(content);

    // AI AUTO-CALCULATION LOGIC
    parsedData.autoCalculated = false;
    parsedData.calculationReason = null;
    parsedData.detectedType = null;

    if (parsedData.issue_date && !parsedData.expiry_date) {
      let matchedRule = null;
      
      // 1. Prioridad: El documentType enviado por la UI
      let mappedKey = null;
      if (documentType === 'health_certificate') mappedKey = 'reconocimiento_medico';
      else if (documentType === 'safety_training') mappedKey = 'certificado_formacion_prl';
      else if (documentType === 'height_work_permit') mappedKey = 'certificado_formacion_altura';
      else if (documentType === 'electrical_permit') mappedKey = 'certificado_instalaciones_electricas';
      
      if (mappedKey && validityRules[mappedKey]) {
        matchedRule = validityRules[mappedKey];
      }

      // 2. Fallback: Buscar palabras clave en el razonamiento de la IA
      if (!matchedRule && parsedData.reasoning) {
        const textLower = parsedData.reasoning.toLowerCase();
        for (const [key, rule] of Object.entries(validityRules)) {
          if (rule.names.some((kw: string) => textLower.includes(kw))) {
            matchedRule = rule;
            break;
          }
        }
      }

      if (matchedRule && matchedRule.validity_months) {
        parsedData.expiry_date = calculateExpiryDate(parsedData.issue_date, matchedRule.validity_months);
        parsedData.autoCalculated = true;
        parsedData.calculationReason = `${matchedRule.reason} (${matchedRule.validity_months} meses desde emisión)`;
      }
    }

    return new Response(JSON.stringify(parsedData), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
