
//#define NEWMETHOD

#python autoDiscard = False

#define ps_3_0

VertexShader(pos : POSITION, nrm : NORMAL, diff : COLOR, uv : TEXCOORD)
{
    uv2D = uv.uv;

    // Lighting
    float4 worldNormal;
    worldNormal.xyz = RotateToWorld(nrm);
    worldNormal.w = 1.0f;

    uvNormal = worldNormal;

    float4 scratch;
    float4 localReflection;

    float3 worldPos = LocalToWorld(pos);

    psPos = worldPos;
    camPos = CAMERA;

    // This missing semi-colon was a mistake, but it actually ended up making it look right in the end so
    float3 up = float3(0, 1, 0)

    camRight = cross(CAMDIR, up);

    float3 worldIncident = normalize(worldPos - CAMERA);

    float3 worldReflection = reflect(worldIncident, worldNormal);

    // Fresnel
    float4 f;

    float2 consts = float2(0.6f, 0.3f);
    f.x = abs(dot(worldIncident, worldNormal));
    f.x = 1.0f - f.x;
    f.y = f.x * f.x * f.x;
    f.y = mad(f.y, consts.x, consts.y);
    FRESNEL = f.y;

    uvReflection = worldReflection * 0.2;

    // Blend
    BLEND = diff.a;

    // Ambient
    worldNormal.w = 1.0f;

    float4 inAmbient;
    inAmbient.x = sqrt(dot(worldNormal, PLANEX));
    inAmbient.y = sqrt(dot(worldNormal, PLANEY));
    inAmbient.z = sqrt(dot(worldNormal, PLANEZ));
    AMBIENT = inAmbient;

    float4 screenPos = LocalToScreen(pos);
    EXTRA = screenPos.xy;

    return screenPos;
}

// Shader model 3 can have more than 4 textures, so I took advantage of that in my version of the mod
sampler2D colour;
samplerCUBE specular;
sampler2D dirt;
samplerCUBE lighting;
sampler2D prevFrame;

PixelShader(float2 uv2D, float3 uvNormal, float3 uvReflection, float3 AMBIENT, float4 BLEND, float4 FRESNEL, float3 EXTRA, float3 psPos, float3 camPos, float3 camRight)
{
    // Calculate the reflection per-pixel for more accuracy
    float3 wpos = psPos;
    float3 incident = normalize(wpos - camPos);
    float3 reflection = reflect(incident, uvNormal);

    float4 cubeMapSample = texCUBE(specular, reflection) * FRESNEL;

    // Areas that point towards the screen will get SSR, while the other areas will revert back to the cubemap
    float SSRStrength = dot(reflection, incident);
    SSRStrength -= 0.75f;
    SSRStrength *= 4.0f;
    SSRStrength = saturate(SSRStrength);
    SSRStrength = sqrt(SSRStrength);

    reflection.y *= 0.3;
    reflection.x = dot(camRight, reflection);
    reflection.x *= 0.3;

    float depth = distance(wpos, camPos);

    // The screen position confuses me, it's kinda -1 to 1 but not really, so I just experimented to find constants that work well enough
    float4 e = EXTRA;
    e.x *= rcp(depth);
    e.y *= rcp(depth);
    e.y = -e.y;
    e.x *= 0.52f;
    e.y *= 0.5f;
    e.y -= 0.495f;
    e.x -= 0.5f;

    e.y += -reflection.y;
    e.x += reflection.x;

    float neg1 = -1.0;
    if (e.x < neg1 || e.y < neg1 || e.x > 0.0 || e.y > 0.0)
        SSRStrength = 0;

    // Random comment that needs to be put here
    float4 SSRReflection = tex2D(prevFrame, e.xy) * FRESNEL;

    // Areas that are damaged will get no reflections
    SSRReflection *= 1-BLEND;
    cubeMapSample *= 1-BLEND;

    // Blend between clean and dirt
    float4 col = lerp(tex2D(colour, uv2D), tex2D(dirt, uv2D), BLEND);

    float4 light = texCUBE(lighting, uvNormal).a * SHADOW;
    light = saturate(mad(AMBIENT, 0.6f, light));
    light = min(light, 0.8);

    float4 SSRCol = col * light + (SSRReflection * 0.75);
    float4 cubeMapCol = lerp(col, cubeMapSample, FRESNEL) * light;

    return lerp(cubeMapCol, SSRCol, SSRStrength);
}