// pro_car_window template

#define ps_3_0

float4 VertexShader(float3 pos : POSITION, float3 nrm : NORMAL, float2 uv : TEXCOORD0)
{
    // c32 = [R(0), 1-R(0), 0, 0]
    // R0 = rotated normal
    float4 worldNormal;
    worldNormal.xyz = RotateToWorld(nrm);
    // position -> world
    float3 incident = LocalToWorld(pos);
    // normalization coords
    normal = worldNormal;
    // compute vtx->eye ray
    // normalize it
    incident = normalize(incident - CAMERA);

    camRight = cross(incident, float3(0, 1, 0));

    psIncident = incident;

    // passthru texture coords
    uv2D = uv.uv;

    // 2*(V dot N)*N - V
    worldNormal.w = 1;
    reflection = reflect(incident, worldNormal);

    // Compute fresnel term approximation
    // f = r(0) + (1.0-R(0)) * pow(1.0 - dot(eye, normal), 5.0 );

    // Fresnel
    float4 f;

    f.x = abs(dot(incident, worldNormal));
    f.x = 1.0f - f.x;
    f.y = f.x * f.x * f.x;
    f.y = mad(f.y, 0.5f, 0.5f);
    FRESNEL = f.y;

    // project position
    float4 sPos = LocalToScreen(pos);
    screenPos = sPos;

    return sPos;
}

sampler2D colour;
samplerCUBE specular;
samplerCUBE diffuse;
sampler2D prevFrame;


float4 PixelShader(float4 FRESNEL, float4 EXTRA, float3 worldPos, float4 screenPos, float3 camPos, float3 psIncident, float3 normal, float3 reflection, float2 uv2D, float3 camRight)
{
    // output.rgb = fresnel*env + specular
    // output.a = (1-fresnel)*brightness

    //return float4(1, 0, 0, 0);

    float3 refl = reflection;

    float SSRStrength = dot(refl, psIncident);
    SSRStrength -= 0.7f;
    SSRStrength = saturate(SSRStrength);
    SSRStrength *= 3.0f;
    SSRStrength = sqrt(SSRStrength);

    refl.y *= 0.5;
    refl.x = dot(refl, camRight);
    refl.x *= 0.5;

    float4 e = screenPos;
    e.y = -e.y;
    e.x *= 0.12f;
    e.y *= 0.12f;
    e.y += 0.495f;
    e.x -= 0.501f;

    e.y += -refl.y;
    e.x += -refl.x;

    float4 c;
    c.rgb = tex2D(prevFrame, e.xy) * SSRStrength;
    c.a = 1-SSRStrength;
    return c;

    float4 c;
    c.rgb = FRESNEL * tex2D(prevFrame, worldPos.xy);
    c.a = saturate(1-FRESNEL * EXTRA);

    c.rgb = saturate(mad(EXTRA, tex2D(prevFrame, worldPos.xy).a, c));

    return c;
}