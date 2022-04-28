#ifndef FUR_GEOMETRY_UNLIT_HLSL
#define FUR_GEOMETRY_UNLIT_HLSL

#include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
#include "./Param.hlsl"
#include "../Common/Common.hlsl"
#include "HLSLSupport.cginc"

struct _Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

struct Varyings
{
    float4 vertex : SV_POSITION;
    float2 uv : TEXCOORD0;
    float fogCoord : TEXCOORD1;
    float factor : TEXCOORD2;
    UNITY_VERTEX_OUTPUT_STEREO
};

Attributes vert(_Attributes input)
{
    Attributes output;
    UNITY_INITIALIZE_OUTPUT(Attributes, output);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    output.positionOS = input.positionOS;
    output.normalOS = input.normalOS;
    output.uv = input.uv;
    return output;
}

void AppendVertex(inout TriangleStream<Varyings> stream, float3 posOS, float2 uv, float factor, Attributes input0)
{
    Varyings output;
    UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(input0, output);
    output.vertex = TransformObjectToHClip(posOS);
    output.uv = TRANSFORM_TEX(uv, _BaseMap);
    output.fogCoord = ComputeFogFactor(output.vertex.z);
    output.factor = factor;
    stream.Append(output);
}

[maxvertexcount(53)]
void geom(triangle Attributes input[3], inout TriangleStream<Varyings> stream)
{
    UNITY_SETUP_INSTANCE_ID(input[0]);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(input[0]);
    float3 startPos0OS = input[0].positionOS.xyz;
    float3 startPos1OS = input[1].positionOS.xyz;
    float3 startPos2OS = input[2].positionOS.xyz;

    float2 prevUv0 = input[0].uv;
    float2 prevUv1 = input[1].uv;
    float2 prevUv2 = input[2].uv;
    float2 topUv = (prevUv0 + prevUv1 + prevUv2) / 3;
    float2 uvInterp0 = topUv - prevUv0;
    float2 uvInterp1 = topUv - prevUv1;
    float2 uvInterp2 = topUv - prevUv2;

    float3 prevPos0OS = startPos0OS;
    float3 prevPos1OS = startPos1OS;
    float3 prevPos2OS = startPos2OS;
    float3 line01OS = prevPos1OS - prevPos0OS;
    float3 line02OS = prevPos2OS - prevPos0OS;
    float3 faceNormalOS = SafeNormalize(cross(line01OS, line02OS));
    faceNormalOS += rand3(topUv) * _RandomDirection;
    faceNormalOS = SafeNormalize(faceNormalOS);

    float3 startCenterPosOS = (prevPos0OS + prevPos1OS + prevPos2OS) / 3;
    float3 topPosOS = startCenterPosOS + faceNormalOS * _FurLength;

    float3 startCenterPosWS = TransformObjectToWorld(startCenterPosOS);
    float3 faceNormalWS = TransformObjectToWorldNormal(faceNormalOS, true);
    float3 windAngle = _Time.w * _WindFreq.xyz;
    float3 windMoveWS = _WindMove.xyz * sin(windAngle + startCenterPosWS * _WindMove.w);
    float3 baseMoveWS = _BaseMove.xyz;
    float3 movedFaceNormalWS = faceNormalWS + (baseMoveWS + windMoveWS);
    float3 movedFaceNormalOS = TransformWorldToObjectNormal(movedFaceNormalWS, true);
    float3 topMovedPosOS = startCenterPosOS + movedFaceNormalOS * _FurLength;

    float prevFactor = 0.0;
    float delta = 1.0 / _FurJoint;

    for (int j = 0; j < _FurJoint; ++j)
    {
        float nextFactor = prevFactor + delta;

        float moveFactor = pow(abs(nextFactor), _BaseMove.w);
        float3 posInterp0OS = lerp(topPosOS, topMovedPosOS, moveFactor) - startPos0OS;
        float3 posInterp1OS = lerp(topPosOS, topMovedPosOS, moveFactor) - startPos1OS;
        float3 posInterp2OS = lerp(topPosOS, topMovedPosOS, moveFactor) - startPos2OS;
        float3 nextPos0OS = startPos0OS + posInterp0OS * nextFactor;
        float3 nextPos1OS = startPos1OS + posInterp1OS * nextFactor;
        float3 nextPos2OS = startPos2OS + posInterp2OS * nextFactor;

        float2 nextUv0 = prevUv0 + uvInterp0 * delta;
        float2 nextUv1 = prevUv1 + uvInterp1 * delta;
        float2 nextUv2 = prevUv2 + uvInterp2 * delta;

        AppendVertex(stream, nextPos0OS, nextUv0, nextFactor, input[0]);
        AppendVertex(stream, prevPos0OS, prevUv0, prevFactor, input[0]);
        AppendVertex(stream, nextPos1OS, nextUv1, nextFactor, input[0]);
        AppendVertex(stream, prevPos1OS, prevUv1, prevFactor, input[0]);
        AppendVertex(stream, nextPos2OS, nextUv2, nextFactor, input[0]);
        AppendVertex(stream, prevPos2OS, prevUv2, prevFactor, input[0]);
        AppendVertex(stream, nextPos0OS, nextUv0, nextFactor, input[0]);
        AppendVertex(stream, prevPos0OS, prevUv0, prevFactor, input[0]);

        prevFactor = nextFactor;

        prevPos0OS = nextPos0OS;
        prevPos1OS = nextPos1OS;
        prevPos2OS = nextPos2OS;

        prevUv0 = nextUv0;
        prevUv1 = nextUv1;
        prevUv2 = nextUv2;

        stream.RestartStrip();
    }

    AppendVertex(stream, prevPos0OS, prevUv0, prevFactor, input[0]);
    AppendVertex(stream, prevPos1OS, prevUv1, prevFactor, input[0]);
    AppendVertex(stream, topMovedPosOS, topUv, 1.0, input[0]);
    AppendVertex(stream, prevPos2OS, prevUv2, prevFactor, input[0]);
    AppendVertex(stream, prevPos0OS, prevUv0, prevFactor, input[0]);
    stream.RestartStrip();
}

float4 frag(Varyings input) : SV_Target
{
    float4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    color *= _BaseColor;
    color *= lerp(1.0 - _Occlusion, 1.0, input.factor);
    color.rgb = clamp(MixFog(color.rgb, input.fogCoord), 0, 1);
    return color;
}

#endif
