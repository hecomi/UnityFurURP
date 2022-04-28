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

struct Attributes {
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
    //UNITY_SETUP_INSTANCE_ID(input); //Insert
    //UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output); //Insert
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    output.positionOS = input.positionOS;
    output.normalOS = input.normalOS;
    output.uv = input.uv;
    return output;
}

void AppendVertex(inout TriangleStream<Varyings> stream, float3 posOS, float3 normalWS, float2 uv, float factor, Attributes input0)
{
    Varyings output;
    //UNITY_INITIALIZE_OUTPUT(Varyings, output);
    //UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(input0, output);
#ifdef SHADOW_CASTER_PASS
    float3 posWS = TransformObjectToWorld(posOS);
    output.vertex = GetShadowPositionHClip(posWS, normalWS);
#else
    output.vertex = TransformObjectToHClip(posOS);
#endif
    output.uv = TRANSFORM_TEX(uv, _BaseMap);
    output.fogCoord = ComputeFogFactor(output.vertex.z);
    output.factor = factor;
    stream.Append(output);
}

[maxvertexcount(53)]
void geom(triangle Attributes input[3], inout TriangleStream<Varyings> stream)
{
    //UNITY_SETUP_INSTANCE_ID(input[0]);
    //UNITY_SETUP_INSTANCE_ID(input[1]);
    //UNITY_SETUP_INSTANCE_ID(input[2]);
    //UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input[0])
    //UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input[1])
    //UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input[2])
    //UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(input[0]);
    //UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(input[1]);
    //UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(input[2]);
    //UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
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

        AppendVertex(stream, nextPos0OS, faceNormalWS, nextUv0, nextFactor, input[0]);
        AppendVertex(stream, prevPos0OS, faceNormalWS, prevUv0, prevFactor, input[0]);
        AppendVertex(stream, nextPos1OS, faceNormalWS, nextUv1, nextFactor, input[0]);
        AppendVertex(stream, prevPos1OS, faceNormalWS, prevUv1, prevFactor, input[0]);
        AppendVertex(stream, nextPos2OS, faceNormalWS, nextUv2, nextFactor, input[0]);
        AppendVertex(stream, prevPos2OS, faceNormalWS, prevUv2, prevFactor, input[0]);
        AppendVertex(stream, nextPos0OS, faceNormalWS, nextUv0, nextFactor, input[0]);
        AppendVertex(stream, prevPos0OS, faceNormalWS, prevUv0, prevFactor, input[0]);

        prevFactor = nextFactor;

        prevPos0OS = nextPos0OS;
        prevPos1OS = nextPos1OS;
        prevPos2OS = nextPos2OS;

        prevUv0 = nextUv0;
        prevUv1 = nextUv1;
        prevUv2 = nextUv2;

        stream.RestartStrip();
    }

    AppendVertex(stream, prevPos0OS, faceNormalWS, prevUv0, prevFactor, input[0]);
    AppendVertex(stream, prevPos1OS, faceNormalWS, prevUv1, prevFactor, input[0]);
    AppendVertex(stream, topMovedPosOS, faceNormalWS, topUv, 1.0, input[0]);
    AppendVertex(stream, prevPos2OS, faceNormalWS, prevUv2, prevFactor, input[0]);
    AppendVertex(stream, prevPos0OS, faceNormalWS, prevUv0, prevFactor, input[0]);
    stream.RestartStrip();
}

void frag(
    Varyings input, 
    out float4 outColor : SV_Target, 
    out float outDepth : SV_Depth)
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    //UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(input, output);
    outColor = outDepth = input.vertex.z / input.vertex.w;
}

#endif
