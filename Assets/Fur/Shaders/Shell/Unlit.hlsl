#ifndef FUR_SHELL_UNLIT_HLSL
#define FUR_SHELL_UNLIT_HLSL

#include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
#include "./Param.hlsl"
#include "../Common/Common.hlsl"
#include "HLSLSupport.cginc"

struct _Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

struct Varyings
{
    float4 vertex : SV_POSITION;
    float2 uv : TEXCOORD0;
    float  fogCoord : TEXCOORD1;
    float  layer : TEXCOORD2;
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
    output.tangentOS = input.tangentOS;
    return output;
}

void AppendShellVertex(inout TriangleStream<Varyings> stream, Attributes input, int index, Attributes input0)
{
    Varyings output = (Varyings)0;
    UNITY_TRANSFER_VERTEX_OUTPUT_STEREO(input0, output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    float moveFactor = pow(abs((float)index / _ShellAmount), _BaseMove.w);
    float3 posOS = input.positionOS.xyz;
    float3 windAngle = _Time.w * _WindFreq.xyz;
    float3 windMove = moveFactor * _WindMove.xyz * sin(windAngle + posOS * _WindMove.w);
    float3 move = moveFactor * _BaseMove.xyz;

    float3 shellDir = normalize(normalInput.normalWS + move + windMove);
    float3 posWS = vertexInput.positionWS + shellDir * (_ShellStep * index);
    float4 posCS = TransformWorldToHClip(posWS);

    if (index > 0)
    {
        float3 viewDirOS = GetViewDirectionOS(posOS);
        float eyeDotN = dot(viewDirOS, input.normalOS);
        if (abs(eyeDotN) < _FaceViewProdThresh) return;
    }
    
    output.vertex = posCS;
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.fogCoord = ComputeFogFactor(posCS.z);
    output.layer = (float)index / _ShellAmount;

    stream.Append(output);
}

[maxvertexcount(53)]
void geom(triangle Attributes input[3], inout TriangleStream<Varyings> stream)
{
    UNITY_SETUP_INSTANCE_ID(input[0]);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(input[0]);
    [loop] for (float i = 0; i < _ShellAmount; ++i)
    {
        [unroll] for (float j = 0; j < 3; ++j)
        {
            AppendShellVertex(stream, input[j], i, input[0]);
        }
        stream.RestartStrip();
    }
}

float4 frag(Varyings input) : SV_Target
{
    float4 furColor = SAMPLE_TEXTURE2D(_FurMap, sampler_FurMap, input.uv * _FurScale);
    float alpha = furColor.r * (1.0 - input.layer);
    if (input.layer > 0.0 && alpha < _AlphaCutout) discard;

    float4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
    float occlusion = lerp(1.0 - _Occlusion, 1.0, input.layer);
    float3 color = baseColor.xyz * occlusion;
    color = clamp(MixFog(color, input.fogCoord), 0, 1);

    return float4(color, alpha);
}

#endif