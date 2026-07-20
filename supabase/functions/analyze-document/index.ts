import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { imageBase64, mimeType, documentType } = await req.json()
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')

    if (!geminiApiKey) {
      throw new Error('GEMINI_API_KEY no está configurado en los secretos de Supabase.')
    }
    if (!imageBase64) {
      throw new Error('No se ha proporcionado ninguna imagen.')
    }

    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiApiKey}`

    const systemPrompt = `Eres un experto en analizar documentos legales, laborales y certificados en España.
El usuario ha indicado que este documento es del tipo: '${documentType || 'Desconocido'}'.
Tu objetivo es extraer la fecha de emisión (issue_date) y la fecha de caducidad (expiry_date).

REGLAS ESPECÍFICAS DE BÚSQUEDA:
1. DNIs y Pasaportes: La caducidad suele estar en el ANVERSO bajo 'VALIDEZ' y la emisión bajo 'FECHA DE EMISIÓN'. El formato corto 'DD MM AA' (ej. '01 01 32') significa siempre el siglo XXI (2032-01-01).
2. Certificados de Seguridad Social o Hacienda (Corriente de pago): Suelen ser válidos por 6 meses. Busca frases como "validez de X meses" desde la fecha de expedición, o "Válido hasta".
3. Cursos PRL, Trabajos en Altura, Riesgo Eléctrico: Busca "Fecha de caducidad", "Válido hasta", "Próximo reciclaje", o suma los años de validez indicados a la fecha del curso.
4. Carnet de Conducir: Fecha de expedición (4a) y fecha de caducidad (4b).

SIEMPRE extrae las fechas y devuélvelas estrictamente en formato YYYY-MM-DD. Si no existe, devuelve null.
IMPORTANTE: Completa siempre el campo "reasoning" explicando paso a paso qué textos y números ves en la imagen relacionados con fechas, y por qué decides asignar o no las fechas de caducidad y emisión.`;

    const payload = {
      contents: [{
        parts: [
          { text: systemPrompt },
          {
            inlineData: {
              mimeType: mimeType || 'image/jpeg',
              data: imageBase64
            }
          }
        ]
      }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "OBJECT",
          properties: {
            issue_date: { type: "STRING", description: "Fecha de emisión en formato YYYY-MM-DD. Null si no existe.", nullable: true },
            expiry_date: { type: "STRING", description: "Fecha de caducidad en formato YYYY-MM-DD. Null si no existe.", nullable: true },
            reasoning: { type: "STRING", description: "Tu razonamiento paso a paso sobre qué fechas ves y por qué." }
          },
          required: ["reasoning"]
        }
      }
    }

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    const result = await response.json();
    if (result.error) {
       throw new Error(result.error.message || 'Error en la API de Gemini');
    }

    const content = result.candidates[0].content.parts[0].text;
    const parsedData = JSON.parse(content);

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
