#ifndef FUR_GEOMETRY_LIT_HLSL
#define FUR_GEOMETRY_LIT_HLSL

#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "./Param.hlsl"
#include "../Common/Common.hlsl"

struct _Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 texcoord : TEXCOORD0;
    float2 lightmapUV : TEXCOORD1;
    uint id : SV_VertexID;
};

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 texcoord : TEXCOORD0;
    float2 lightmapUV : TEXCOORD1;
    uint id : TEXCOORD2;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float2 uv : TEXCOORD3;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 4);
    float4 fogFactorAndVertexLight : TEXCOORD5; // x: fogFactor, yzw: vertex light
    float factor : TEXCOORD6;
};

Attributes vert(_Attributes input)
{
    FurMoverData data = _Buffer[input.id];

    float time = _Time.y;
    if (abs(time - data.time) > 1e-3)
    {
        float3 targetPosWS = TransformObjectToWorld(input.positionOS.xyz);
        float3 dPosWS = targetPosWS - data.posWS;
        float3 forceWS = _Spring * dPosWS - data.velocityWS * _Damper + float3(0.0, _Gravity, 0.0);
        float3 normalWS = TransformObjectToWorldNormal(input.normalOS, true);
        float dt = 1.0 / 60;
        data.velocityWS += forceWS * dt;
        data.posWS += data.velocityWS * dt;
        data.dPosWS = (data.posWS - targetPosWS) * _MoveScale;
        float move = length(data.dPosWS);
        data.dPosWS = min(move, 1.0) / max(move, 0.01) * data.dPosWS;
        data.time = time;
        _Buffer[input.id] = data;
    }

    return (Attributes)input;
}

void AppendVertex(
    inout TriangleStream<Varyings> stream, 
    float3 posOS, 
    float3 normalOS, 
    float2 uv, 
    float2 lightmapUV,
    float factor)
{
    Varyings output = (Varyings)0;

    VertexPositionInputs vertexInput = GetVertexPositionInputs(posOS);
    output.positionCS = vertexInput.positionCS;
    output.positionWS = vertexInput.positionWS;
    output.normalWS = TransformObjectToWorldNormal(normalOS, true);
    output.uv = uv;
    output.factor = factor;

    float3 vertexLight = VertexLighting(output.positionWS, output.normalWS);
    float fogFactor = ComputeFogFactor(output.positionCS.z);
    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

    OUTPUT_LIGHTMAP_UV(lightmapUV, unity_LightmapST, output.lightmapUV);
    OUTPUT_SH(output.normalWS, output.vertexSH);

    stream.Append(output);
}

[maxvertexcount(45)]
void geom(triangle Attributes input[3], inout TriangleStream<Varyings> stream)
{
    uint id0 = input[0].id;
    uint id1 = input[1].id;
    uint id2 = input[2].id;

    float3 startPos0OS = input[0].positionOS.xyz;
    float3 startPos1OS = input[1].positionOS.xyz;
    float3 startPos2OS = input[2].positionOS.xyz;

    float2 prevUv0 = TRANSFORM_TEX(input[0].texcoord, _BaseMap);
    float2 prevUv1 = TRANSFORM_TEX(input[1].texcoord, _BaseMap);
    float2 prevUv2 = TRANSFORM_TEX(input[2].texcoord, _BaseMap);
    float2 topUv = (prevUv0 + prevUv1 + prevUv2) / 3;
    float2 uvInterp0 = topUv - prevUv0;
    float2 uvInterp1 = topUv - prevUv1;
    float2 uvInterp2 = topUv - prevUv2;

    float2 prevLightmapUv0 = input[0].lightmapUV;
    float2 prevLightmapUv1 = input[1].lightmapUV;
    float2 prevLightmapUv2 = input[2].lightmapUV;
    float2 topLightmapUv = (prevLightmapUv0 + prevLightmapUv1 + prevLightmapUv2) / 3;
    float2 lightmapUvInterp0 = topLightmapUv - prevLightmapUv0;
    float2 lightmapUvInterp1 = topLightmapUv - prevLightmapUv1;
    float2 lightmapUvInterp2 = topLightmapUv - prevLightmapUv2;

    float3 prevPos0OS = startPos0OS;
    float3 prevPos1OS = startPos1OS;
    float3 prevPos2OS = startPos2OS;
    float3 line01OS = prevPos1OS - prevPos0OS;
    float3 line02OS = prevPos2OS - prevPos0OS;
    float3 faceNormalOS = SafeNormalize(cross(line01OS, line02OS));
    float3 origFaceNormalOS = faceNormalOS;
    faceNormalOS += rand3(topUv) * _RandomDirection;
    faceNormalOS = SafeNormalize(faceNormalOS);

    float3 startCenterPosOS = (prevPos0OS + prevPos1OS + prevPos2OS) / 3;
    float3 topPosOS = startCenterPosOS + faceNormalOS * _FurLength;

    float3 startCenterPosWS = TransformObjectToWorld(startCenterPosOS);
    float3 faceNormalWS = TransformObjectToWorldNormal(faceNormalOS, true);
    float3 windAngle = _Time.w * _WindFreq.xyz;
    float3 windMoveWS = _WindMove.xyz * sin(windAngle + startCenterPosWS * _WindMove.w);
    float3 baseMoveWS = _BaseMove.xyz;
    float3 vertMoveWS = (_Buffer[id0].dPosWS + _Buffer[id1].dPosWS + _Buffer[id2].dPosWS) / 3;
    float3 movedFaceNormalWS = faceNormalWS + (baseMoveWS + windMoveWS) + vertMoveWS;
    float3 movedFaceNormalOS = TransformWorldToObjectNormal(movedFaceNormalWS, true);
    float3 topMovedPosOS = startCenterPosOS + movedFaceNormalOS * _FurLength;

    float3 prevCenterPosOS = startCenterPosOS;
    float3 prevNormal0OS = origFaceNormalOS;
    float3 prevNormal1OS = origFaceNormalOS;
    float3 prevNormal2OS = origFaceNormalOS;

    float prevFactor = 0.0;
    float delta = 1.0 / _FurJoint;

    for (int j = 0; j < _FurJoint; ++j)
    {
        float nextFactor = prevFactor + delta;

        float moveFactor = pow(abs(nextFactor), _BaseMove.w);
        float3 lerpMovedTopPosOS = lerp(topPosOS, topMovedPosOS, moveFactor);
        float3 posInterp0OS = lerpMovedTopPosOS - startPos0OS;
        float3 posInterp1OS = lerpMovedTopPosOS - startPos1OS;
        float3 posInterp2OS = lerpMovedTopPosOS - startPos2OS;
        float3 nextPos0OS = startPos0OS + posInterp0OS * nextFactor;
        float3 nextPos1OS = startPos1OS + posInterp1OS * nextFactor;
        float3 nextPos2OS = startPos2OS + posInterp2OS * nextFactor;
        float3 nextCenterPosOS = (nextPos0OS + nextPos1OS + nextPos2OS) / 3;

        float3 basePosOS = (nextCenterPosOS + prevCenterPosOS) / 2;
        float3 movedNormal0OS = SafeNormalize(nextPos0OS - basePosOS);
        float3 movedNormal1OS = SafeNormalize(nextPos1OS - basePosOS);
        float3 movedNormal2OS = SafeNormalize(nextPos2OS - basePosOS);
        float3 nextNormal0OS = SafeNormalize(lerp(origFaceNormalOS, movedNormal0OS, _NormalFactor));
        float3 nextNormal1OS = SafeNormalize(lerp(origFaceNormalOS, movedNormal1OS, _NormalFactor));
        float3 nextNormal2OS = SafeNormalize(lerp(origFaceNormalOS, movedNormal2OS, _NormalFactor));

        float2 nextUv0 = prevUv0 + uvInterp0 * delta;
        float2 nextUv1 = prevUv1 + uvInterp1 * delta;
        float2 nextUv2 = prevUv2 + uvInterp2 * delta;

        float2 nextLightmapUv0 = prevUv0 + lightmapUvInterp0 * delta;
        float2 nextLightmapUv1 = prevUv1 + lightmapUvInterp1 * delta;
        float2 nextLightmapUv2 = prevUv2 + lightmapUvInterp2 * delta;

        AppendVertex(stream, nextPos0OS, nextNormal0OS, nextUv0, nextLightmapUv0, nextFactor);
        AppendVertex(stream, prevPos0OS, prevNormal0OS, prevUv0, prevLightmapUv0, prevFactor);
        AppendVertex(stream, nextPos1OS, nextNormal1OS, nextUv1, nextLightmapUv1, nextFactor);
        AppendVertex(stream, prevPos1OS, prevNormal1OS, prevUv1, prevLightmapUv1, prevFactor);
        AppendVertex(stream, nextPos2OS, nextNormal2OS, nextUv2, nextLightmapUv2, nextFactor);
        AppendVertex(stream, prevPos2OS, prevNormal2OS, prevUv2, prevLightmapUv2, prevFactor);
        AppendVertex(stream, nextPos0OS, nextNormal0OS, nextUv0, nextLightmapUv0, nextFactor);
        AppendVertex(stream, prevPos0OS, prevNormal0OS, prevUv0, prevLightmapUv0, prevFactor);

        prevFactor = nextFactor;

        prevPos0OS = nextPos0OS;
        prevPos1OS = nextPos1OS;
        prevPos2OS = nextPos2OS;

        prevCenterPosOS = (nextPos0OS + nextPos1OS + nextPos2OS) / 3;

        prevNormal0OS = nextNormal0OS;
        prevNormal1OS = nextNormal1OS;
        prevNormal2OS = nextNormal2OS;

        prevUv0 = nextUv0;
        prevUv1 = nextUv1;
        prevUv2 = nextUv2;

        prevLightmapUv0 = nextLightmapUv0;
        prevLightmapUv1 = nextLightmapUv1;
        prevLightmapUv2 = nextLightmapUv2;

        stream.RestartStrip();
    }

    float3 topNormalOS = SafeNormalize(topMovedPosOS - prevCenterPosOS);
    topNormalOS = SafeNormalize(lerp(faceNormalOS, topNormalOS, _NormalFactor));
    AppendVertex(stream, prevPos0OS, prevNormal0OS, prevUv0, prevLightmapUv0, prevFactor);
    AppendVertex(stream, prevPos1OS, prevNormal1OS, prevUv1, prevLightmapUv1, prevFactor);
    AppendVertex(stream, topMovedPosOS, topNormalOS, topUv, topLightmapUv, 1.0);
    AppendVertex(stream, prevPos2OS, prevNormal2OS, prevUv2, prevLightmapUv2, prevFactor);
    AppendVertex(stream, prevPos0OS, prevNormal0OS, prevUv0, prevLightmapUv0, prevFactor);
    stream.RestartStrip();
}

float4 frag(Varyings input) : SV_Target
{
    SurfaceData surfaceData = (SurfaceData)0;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);
    surfaceData.occlusion = lerp(sqrt(abs(1.0 - _Occlusion)), 1.0, input.factor);
    surfaceData.albedo *= surfaceData.occlusion;

    InputData inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.normalWS = SafeNormalize(input.normalWS);
    inputData.viewDirectionWS = SafeNormalize(GetCameraPositionWS() - input.positionWS);
#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);

#if 1
    float4 color = UniversalFragmentPBR(inputData, surfaceData);
    ApplyRimLight(color.rgb, inputData.positionWS, inputData.viewDirectionWS, inputData.normalWS);
    color.rgb += _AmbientColor.rgb;
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
#else
    float4 color = float4(inputData.normalWS, 1.0);
#endif

    return color;
}

#endif
