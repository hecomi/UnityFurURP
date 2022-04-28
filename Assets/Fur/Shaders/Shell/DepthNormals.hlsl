#ifndef FUR_SHELL_DEPTH_NORMALS_HLSL
#define FUR_SHELL_DEPTH_NORMALS_HLSL

#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"
#include "./Param.hlsl"
// For VR single pass instance compability:
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct Attributes
{
    half4 positionOS : POSITION;
    half3 normalOS : NORMAL;
    half4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2g
{
    half4 positionOS : POSITION;
    half3 normalOS : NORMAL;
    half4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct g2f
{
    float4 vertex : SV_POSITION;
    float2 uv : TEXCOORD0;
    //float  fogCoord : TEXCOORD1;
    float  layer : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    float3 tangentWS : TEXCOORD3;
    float3 posWS : TEXCOORD4;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

v2g vert(Attributes input)
{
    v2g output = (v2g)0;
    // setup the instanced id
    UNITY_SETUP_INSTANCE_ID(input);
    // set all values in the "v2g output" to 0.0
    // This is the URP version of UNITY_INITIALIZE_OUTPUT()
    ZERO_INITIALIZE(v2g, output);
    // copy instance id in the "Attributes input" to the "v2g output"
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    output.positionOS = input.positionOS;
    output.normalOS = input.normalOS;
    output.tangentOS = input.tangentOS;
    output.uv = input.uv;
    return output;
}

void AppendShellVertex(inout TriangleStream<g2f> stream, v2g input, int index)
{
    g2f output = (g2f)0;
    UNITY_SETUP_INSTANCE_ID(input);
    // set all values in the g2f output to 0.0
    ZERO_INITIALIZE(g2f, output);

    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    float clampedShellAmount = clamp(_ShellAmount, 1, 13);
    _ShellStep = _TotalShellStep / clampedShellAmount;

    float moveFactor = pow(abs((float)index / clamp(_ShellAmount, 1, 13)), _BaseMove.w);
    float3 posOS = input.positionOS.xyz;
    float3 windAngle = _Time.w * _WindFreq.xyz;
    float3 windMove = moveFactor * _WindMove.xyz * sin(windAngle + posOS * _WindMove.w);
    float3 move = moveFactor * _BaseMove.xyz;

    float3 shellDir = SafeNormalize(normalInput.normalWS + move + windMove);
    float FurLength = SAMPLE_TEXTURE2D_LOD(_FurLengthMap, sampler_FurLengthMap, input.uv / _BaseMap_ST.xy, 0).x;
    float3 posWS = vertexInput.positionWS + shellDir * (_ShellStep * index * FurLength * _FurLengthIntensity);
    float4 posCS = TransformWorldToHClip(posWS);

    output.vertex = posCS;
    output.posWS = posWS;
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.layer = (float)index / clamp(_ShellAmount, 1, 13);

    output.normalWS = normalInput.normalWS;
    output.tangentWS = normalInput.tangentWS;


    stream.Append(output);
}

// For geometry shader instancing, no clamp on _ShellAmount.
void AppendShellVertexInstancing(inout TriangleStream<g2f> stream, v2g input, int index)
{
    g2f output = (g2f)0;
    UNITY_SETUP_INSTANCE_ID(input);
    // set all values in the g2f output to 0.0
    ZERO_INITIALIZE(g2f, output);

    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    _ShellStep = _TotalShellStep / _ShellAmount;

    float moveFactor = pow(abs((float)index / _ShellAmount), _BaseMove.w);
    float3 posOS = input.positionOS.xyz;
    float3 windAngle = _Time.w * _WindFreq.xyz;
    float3 windMove = moveFactor * _WindMove.xyz * sin(windAngle + posOS * _WindMove.w);
    float3 move = moveFactor * _BaseMove.xyz;

    float3 shellDir = SafeNormalize(normalInput.normalWS + move + windMove);
    float FurLength = SAMPLE_TEXTURE2D_LOD(_FurLengthMap, sampler_FurLengthMap, input.uv / _BaseMap_ST.xy, 0).x;
    float3 posWS = vertexInput.positionWS + shellDir * (_ShellStep * index * FurLength * _FurLengthIntensity);
    float4 posCS = TransformWorldToHClip(posWS);

    output.vertex = posCS;
    output.posWS = posWS;
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.layer = (float)index / _ShellAmount;

    output.normalWS = normalInput.normalWS;
    output.tangentWS = normalInput.tangentWS;


    stream.Append(output);
}

//-----------------------------------(below) For Microsoft Shader Model > 4.1-----------------------------------
// See "Lit.hlsl" for more information.
#if defined(_GEOM_INSTANCING)
[instance(3)]
[maxvertexcount(39)]
void geom(triangle v2g input[3], inout TriangleStream<g2f> stream, uint instanceID : SV_GSInstanceID)
{
    // 13 is calculated manually, because "maxvertexcount" is 39 in "Lit.hlsl", keep all passes to have the smallest (39 now).
    // If not, DepthNormals will be incorrect and Depth Priming (DepthNormal Mode) won't work.
    // "39 / 3 = 13", 3 means 3 vertices of a tirangle.
    [loop] for (float i = 0 + (instanceID * 13); i < _ShellAmount; ++i)
    {
        [unroll] for (float j = 0; j < 3; ++j)
        {
            AppendShellVertexInstancing(stream, input[j], i);
        }
        stream.RestartStrip();
    }
}
//-----------------------------------(above) For Microsoft Shader Model > 4.1-----------------------------------

//-----------------------------------(below) For Microsoft Shader Model < 4.1-----------------------------------
#else
[maxvertexcount(39)]
void geom(triangle v2g input[3], inout TriangleStream<g2f> stream)
{
    [loop] for (float i = 0; i < clamp(_ShellAmount, 1, 13); ++i)
    {
        [unroll] for (float j = 0; j < 3; ++j)
        {
            AppendShellVertex(stream, input[j], i);
        }
        stream.RestartStrip();
    }
}
#endif
//-----------------------------------(above) For Microsoft Shader Model < 4.1-----------------------------------

float4 frag(g2f input) : SV_Target
{
    float4 furColor = SAMPLE_TEXTURE2D(_FurMap, sampler_FurMap, input.uv / _BaseMap_ST.xy * _FurScale);
    float alpha = furColor.r * (1.0 - input.layer);
    if (input.layer > 0.0 && alpha < _AlphaCutout) discard;

    float3 viewDirWS = SafeNormalize(GetCameraPositionWS() - input.posWS);
    half3 normalTS = UnpackNormalScale(
        SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv / _BaseMap_ST.xy * _FurScale),
        _NormalScale);
    float3 bitangent = SafeNormalize(viewDirWS.y * cross(input.normalWS, input.tangentWS));
    float3 normalWS = SafeNormalize(TransformTangentToWorld(
        normalTS,
        float3x3(input.tangentWS, bitangent, input.normalWS)));

    // Stores World Space Normal to "_CameraNormalsTexture", no depth needed currently.
    return float4(NormalizeNormalPerPixel(normalWS), 0.0);

}

#endif