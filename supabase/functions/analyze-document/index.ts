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
    const openAiApiKey = Deno.env.get('OPENAI_API_KEY')

    if (!openAiApiKey) {
      throw new Error('OPENAI_API_KEY no está configurado en los secretos de Supabase.')
    }
    if (!imageBase64) {
      throw new Error('No se ha proporcionado ninguna imagen.')
    }

    const payload = {
      model: "gpt-4o",
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content: "Eres un asistente experto en analizar documentos legales, DNIs, pasaportes y certificados laborales. Extrae la fecha de emisión (issue_date) y la fecha de caducidad (expiry_date) de los documentos que se te envían en las imágenes. Si no tiene una de estas fechas, omite el campo o devuélvelo como null. Devuelve un objeto JSON con el siguiente formato estricto: {\"issue_date\": \"YYYY-MM-DD\", \"expiry_date\": \"YYYY-MM-DD\"}. Si el documento es ilegible o no es válido, devuelve {\"error\": \"Documento inválido o fechas ilegibles\"}."
        },
        {
          role: "user",
          content: [
            { type: "text", text: "Por favor extrae las fechas de este documento." },
            {
              type: "image_url",
              image_url: {
                url: `data:${mimeType || 'image/jpeg'};base64,${imageBase64}`
              }
            }
          ]
        }
      ],
      max_tokens: 300,
    }

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${openAiApiKey}`
      },
      body: JSON.stringify(payload)
    });

    const result = await response.json();
    if (result.error) {
       throw new Error(result.error.message || 'Error en la API de OpenAI');
    }

    const content = result.choices[0].message.content;
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
