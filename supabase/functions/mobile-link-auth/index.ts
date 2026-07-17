import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Configuración de CORS
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Manejo de preflight request (CORS)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { token } = await req.json()

    if (!token) {
      return new Response(
        JSON.stringify({ error: 'Token is required' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '' // Service Role Key para evadir RLS temporalmente y usar Admin API
    )

    // 1. Validar token
    const { data: tokenData, error: fetchError } = await supabaseAdmin
      .from('mobile_link_tokens')
      .select('user_id, status, expires_at')
      .eq('token', token)
      .single()

    if (fetchError || !tokenData) {
      return new Response(
        JSON.stringify({ error: 'Invalid token' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    if (tokenData.status !== 'pending') {
      return new Response(
        JSON.stringify({ error: 'Token already used or expired' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    if (new Date(tokenData.expires_at) < new Date()) {
      return new Response(
        JSON.stringify({ error: 'Token has expired' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    // 2. Obtener el email del usuario para generar el enlace
    const { data: userData, error: userError } = await supabaseAdmin.auth.admin.getUserById(tokenData.user_id)
    
    if (userError || !userData || !userData.user) {
      return new Response(
        JSON.stringify({ error: 'User not found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    const userEmail = userData.user.email

    if (!userEmail) {
      return new Response(
        JSON.stringify({ error: 'User has no email' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    // 3. Generar session para el usuario
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'magiclink',
      email: userEmail,
    })

    if (authError || !authData || !authData.properties) {
      return new Response(
        JSON.stringify({ error: 'Failed to generate auth token' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
      )
    }

    // 4. Marcar token como usado
    await supabaseAdmin
      .from('mobile_link_tokens')
      .update({ status: 'used', used_at: new Date().toISOString() })
      .eq('token', token)

    // Devolver el OTP y email para que la app móvil inicie sesión
    return new Response(
      JSON.stringify({
        email_otp: authData.properties.email_otp,
        email: userEmail,
        user_id: tokenData.user_id
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
