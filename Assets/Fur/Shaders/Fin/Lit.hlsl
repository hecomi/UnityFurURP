#ifndef FUR_FIN_LIT_HLSL
#define FUR_FIN_LIT_HLSL

#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "./Param.hlsl"
#include "../Common/Common.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 texcoord : TEXCOORD0;
    float2 lightmapUV : TEXCOORD1;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float2 uv : TEXCOORD2;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 3);
    float4 fogFactorAndVertexLight : TEXCOORD4; // x: fogFactor, yzw: vertex light
    float2 finUv : TEXCOORD5;
    float3 finTangentWS : TEXCOORD6;
};

Attributes vert(Attributes input)
{
    return input;
}

void AppendFinVertex(
    inout TriangleStream<Varyings> stream, 
    float2 uv, 
    float2 lightmapUV, 
    float3 posOS, 
    float3 normalOS, 
    float2 finUv,
    float3 finSideDirWS)
{
    Varyings output = (Varyings)0;

    VertexPositionInputs vertexInput = GetVertexPositionInputs(posOS);
    output.positionCS = vertexInput.positionCS;
    output.positionWS = vertexInput.positionWS;
    output.normalWS = TransformObjectToWorldNormal(normalOS);
    output.uv = uv;
    output.finUv = finUv;
    output.finTangentWS = SafeNormalize(cross(output.normalWS, finSideDirWS));

    float3 vertexLight = VertexLighting(output.positionWS, output.normalWS);
    float fogFactor = ComputeFogFactor(output.positionCS.z);
    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

    OUTPUT_LIGHTMAP_UV(lightmapUV, unity_LightmapST, output.lightmapUV);
    OUTPUT_SH(output.normalWS, output.vertexSH);

    stream.Append(output);
}

void AppendFinVertices(
    inout TriangleStream<Varyings> stream,
    Attributes input0,
    Attributes input1,
    Attributes input2)
{
    float3 normalOS0 = input0.normalOS;

    float3 posOS0 = input0.positionOS.xyz;
    float3 lineOS01 = input1.positionOS.xyz - posOS0;
    float3 lineOS02 = input2.positionOS.xyz - posOS0;
    float3 posOS3 = posOS0 + (lineOS01 + lineOS02) / 2;

    float2 uv0 = TRANSFORM_TEX(input0.texcoord, _BaseMap);
    float2 uv12 = (TRANSFORM_TEX(input1.texcoord, _BaseMap) + TRANSFORM_TEX(input2.texcoord, _BaseMap)) / 2;
    float2 lightmapUV0 = input0.lightmapUV;
    float2 lightmapUV12 = (input1.lightmapUV + input2.lightmapUV) / 2;
    float uvOffset = length(uv0);
    float uvXScale = length(uv0 - uv12) * _Density;

    float3 dir = normalOS0;
    dir += rand3(input0.texcoord) * _RandomDirection;
    dir = normalize(dir);
    float3 dirWS = TransformObjectToWorldNormal(dir);
    float3 posWS = TransformObjectToWorld(posOS0);
    float finStep = _FinLength / _FinJointNum;
    float3 windAngle = _Time.w * _WindFreq.xyz;
    float3 windMoveWS = _WindMove.xyz * sin(windAngle + posWS * _WindMove.w);
    float3 baseMoveWS = _BaseMove.xyz;
    float3 finSideDirOS = normalize(posOS3 - posOS0);
    float3 finSideDirWS = TransformObjectToWorldDir(finSideDirOS);

    [unroll]
    for (int j = 0; j < 2; ++j)
    {
        float3 posBeginOS = posOS0;
        float3 posEndOS = posOS3;
        float uvX1 = uvOffset;
        float uvX2 = uvOffset + uvXScale;

        [loop] 
        for (int i = 0; i <= _FinJointNum; ++i)
        {
            float finFactor = (float) i / _FinJointNum;
            float moveFactor = pow(abs(finFactor), _BaseMove.w);
            float3 moveWS = SafeNormalize(dirWS + (baseMoveWS + windMoveWS) * moveFactor) * finStep;
            float3 moveOS = TransformWorldToObjectDir(moveWS, false);
            posBeginOS += moveOS;
            posEndOS += moveOS;
            float3 dirOS03 = normalize(posEndOS - posBeginOS);
            float3 faceNormalOS = normalize(cross(dirOS03, moveOS));
            if (j == 0)
            {
                
                float3 finNormalOS = normalize(lerp(normalOS0, faceNormalOS, _FaceNormalFactor));
                AppendFinVertex(stream, uv0, lightmapUV0, posBeginOS, finNormalOS, float2(uvX1, finFactor), finSideDirWS);
                AppendFinVertex(stream, uv12, lightmapUV12, posEndOS, finNormalOS, float2(uvX2, finFactor), finSideDirWS);
            }
            else
            {
                faceNormalOS *= -1.0;
                float3 finNormalOS = normalize(lerp(normalOS0, faceNormalOS, _FaceNormalFactor));
                AppendFinVertex(stream, uv12, lightmapUV12, posEndOS, finNormalOS, float2(uvX2, finFactor), finSideDirWS);
                AppendFinVertex(stream, uv0, lightmapUV0, posBeginOS, finNormalOS, float2(uvX1, finFactor), finSideDirWS);
            }
        }

        stream.RestartStrip();
    }
}

[maxvertexcount(39)]
void geom(triangle Attributes input[3], inout TriangleStream<Varyings> stream)
{
#ifdef DRAW_ORIG_POLYGON
    for (int i = 0; i < 3; ++i)
    {
        Varyings output = (Varyings)0;

        VertexPositionInputs vertexInput = GetVertexPositionInputs(input[i].positionOS.xyz);
        output.positionCS = vertexInput.positionCS;
        output.positionWS = vertexInput.positionWS;
        output.normalWS = TransformObjectToWorldNormal(input[i].normalOS);
        output.uv = TRANSFORM_TEX(input[i].texcoord, _BaseMap);
        output.finUv = float2(-1.0, -1.0);

        float3 vertexLight = VertexLighting(vertexInput.positionWS, output.normalWS);
        float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
        output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

        OUTPUT_LIGHTMAP_UV(input[i].lightmapUV, unity_LightmapST, output.lightmapUV);
        OUTPUT_SH(output.normalWS, output.vertexSH);

        stream.Append(output);
    }
    stream.RestartStrip();
#endif

    float3 lineOS01 = (input[1].positionOS - input[0].positionOS).xyz;
    float3 lineOS02 = (input[2].positionOS - input[0].positionOS).xyz;
    float3 normalOS = normalize(cross(lineOS01, lineOS02));
    float3 centerOS = (input[0].positionOS + input[1].positionOS + input[2].positionOS).xyz / 3;
    float3 viewDirOS = GetViewDirectionOS(centerOS);
    float eyeDotN = dot(viewDirOS, normalOS);
    if (abs(eyeDotN) > _FaceViewProdThresh) return;

    AppendFinVertices(stream, input[0], input[1], input[2]);
}

float4 frag(Varyings input) : SV_Target
{
    float4 furColor = SAMPLE_TEXTURE2D(_FurMap, sampler_FurMap, input.finUv);
    if (input.finUv.x >= 0.0 && furColor.a < _AlphaCutout) discard;

    float3 viewDirWS = SafeNormalize(GetCameraPositionWS() - input.positionWS);
    float3 normalTS = UnpackNormalScale(
        SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.finUv),
        _NormalScale);
    float3 bitangent = SafeNormalize(viewDirWS.y * cross(input.normalWS, input.finTangentWS));
    float3 normalWS = SafeNormalize(TransformTangentToWorld(
        normalTS, 
        float3x3(input.finTangentWS, bitangent, input.normalWS)));

    SurfaceData surfaceData = (SurfaceData)0;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);
    surfaceData.occlusion = sqrt(lerp(1.0 - _Occlusion, 1.0, max(input.finUv.y, 0.0)));
    surfaceData.albedo *= surfaceData.occlusion;

    InputData inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.normalWS = normalWS;
    inputData.viewDirectionWS = viewDirWS;
#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);

    float4 color = UniversalFragmentPBR(inputData, surfaceData);
    ApplyRimLight(color.rgb, input.positionWS, viewDirWS, input.normalWS);
    color.rgb += _AmbientColor.rgb;
    color.rgb = MixFog(color.rgb, inputData.fogCoord);

    return color;
}

#endif
