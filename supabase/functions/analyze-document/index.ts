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
    const { imageBase64, mimeType } = await req.json()
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')

    if (!geminiApiKey) {
      throw new Error('GEMINI_API_KEY no está configurado en los secretos de Supabase.')
    }
    if (!imageBase64) {
      throw new Error('No se ha proporcionado ninguna imagen.')
    }

    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiApiKey}`

    const payload = {
      contents: [{
        parts: [
          { text: "Eres un experto en analizar DNIs, pasaportes y certificados. Extrae la fecha de emisión (issue_date) y la fecha de caducidad (expiry_date). IMPORTANTE: En los DNI españoles, la fecha de caducidad aparece bajo el texto 'VALIDEZ' y la emisión bajo 'FECHA DE EMISIÓN', frecuentemente en formato 'DD MM AA' (ej. '01 01 32' significa 2032-01-01). Convierte cualquier fecha encontrada al formato estricto: {\"issue_date\": \"YYYY-MM-DD\", \"expiry_date\": \"YYYY-MM-DD\"}. Si el documento definitivamente no tiene caducidad o emisión, devuelve null para ese campo. Analiza meticulosamente toda la imagen." },
          {
            inlineData: {
              mimeType: mimeType || 'image/jpeg',
              data: imageBase64
            }
          }
        ]
      }],
      generationConfig: {
        responseMimeType: "application/json"
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
