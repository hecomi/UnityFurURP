#ifndef FUR_FIN_LIT_HLSL
#define FUR_FIN_LIT_HLSL

#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "./FurFinParam.hlsl"
#include "./FurCommon.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
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
};

struct HsConstantOutput
{
    float fTessFactor[3]    : SV_TessFactor;
    float fInsideTessFactor : SV_InsideTessFactor;
    float3 f3B210 : POS3;
    float3 f3B120 : POS4;
    float3 f3B021 : POS5;
    float3 f3B012 : POS6;
    float3 f3B102 : POS7;
    float3 f3B201 : POS8;
    float3 f3B111 : CENTER;
    float3 f3N110 : NORMAL3;
    float3 f3N011 : NORMAL4;
    float3 f3N101 : NORMAL5;
};

Attributes vert(Attributes input)
{
    return input;
}

[domain("tri")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[patchconstantfunc("hullConst")]
[outputcontrolpoints(3)]
Attributes hull(InputPatch<Attributes, 3> input, uint id : SV_OutputControlPointID)
{
    return input[id];
}

HsConstantOutput hullConst(InputPatch<Attributes, 3> i)
{
    HsConstantOutput o = (HsConstantOutput)0;

    float distance = length(float3(UNITY_MATRIX_MV[0][3], UNITY_MATRIX_MV[1][3], UNITY_MATRIX_MV[2][3]));
    float factor = (_TessMaxDist - _TessMinDist) / max(distance - _TessMinDist, 0.01);
    factor = min(factor, 1.0);
    factor *= _TessFactor;

    o.fTessFactor[0] = o.fTessFactor[1] = o.fTessFactor[2] = factor;
    o.fInsideTessFactor = factor;

    float3 f3B003 = i[0].positionOS.xyz;
    float3 f3B030 = i[1].positionOS.xyz;
    float3 f3B300 = i[2].positionOS.xyz;

    float3 f3N002 = i[0].normalOS;
    float3 f3N020 = i[1].normalOS;
    float3 f3N200 = i[2].normalOS;
        
    o.f3B210 = ((2.0 * f3B003) + f3B030 - (dot((f3B030 - f3B003), f3N002) * f3N002)) / 3.0;
    o.f3B120 = ((2.0 * f3B030) + f3B003 - (dot((f3B003 - f3B030), f3N020) * f3N020)) / 3.0;
    o.f3B021 = ((2.0 * f3B030) + f3B300 - (dot((f3B300 - f3B030), f3N020) * f3N020)) / 3.0;
    o.f3B012 = ((2.0 * f3B300) + f3B030 - (dot((f3B030 - f3B300), f3N200) * f3N200)) / 3.0;
    o.f3B102 = ((2.0 * f3B300) + f3B003 - (dot((f3B003 - f3B300), f3N200) * f3N200)) / 3.0;
    o.f3B201 = ((2.0 * f3B003) + f3B300 - (dot((f3B300 - f3B003), f3N002) * f3N002)) / 3.0;

    float3 f3E = (o.f3B210 + o.f3B120 + o.f3B021 + o.f3B012 + o.f3B102 + o.f3B201) / 6.0;
    float3 f3V = (f3B003 + f3B030 + f3B300) / 3.0;
    o.f3B111 = f3E + ((f3E - f3V) / 2.0);
    
    float fV12 = 2.0 * dot(f3B030 - f3B003, f3N002 + f3N020) / dot(f3B030 - f3B003, f3B030 - f3B003);
    float fV23 = 2.0 * dot(f3B300 - f3B030, f3N020 + f3N200) / dot(f3B300 - f3B030, f3B300 - f3B030);
    float fV31 = 2.0 * dot(f3B003 - f3B300, f3N200 + f3N002) / dot(f3B003 - f3B300, f3B003 - f3B300);
    o.f3N110 = normalize(f3N002 + f3N020 - fV12 * (f3B030 - f3B003));
    o.f3N011 = normalize(f3N020 + f3N200 - fV23 * (f3B300 - f3B030));
    o.f3N101 = normalize(f3N200 + f3N002 - fV31 * (f3B003 - f3B300));
           
    return o;
}

[domain("tri")]
Attributes domain(
    HsConstantOutput hsConst, 
    const OutputPatch<Attributes, 3> i,
    float3 bary : SV_DomainLocation)
{
    Attributes o = (Attributes)0;

    float fU = bary.x;
    float fV = bary.y;
    float fW = bary.z;
    float fUU = fU * fU;
    float fVV = fV * fV;
    float fWW = fW * fW;
    float fUU3 = fUU * 3.0f;
    float fVV3 = fVV * 3.0f;
    float fWW3 = fWW * 3.0f;
    
    o.positionOS = float4(
        i[0].positionOS.xyz * fWW * fW +
        i[1].positionOS.xyz * fUU * fU +
        i[2].positionOS.xyz * fVV * fV +
        hsConst.f3B210 * fWW3 * fU +
        hsConst.f3B120 * fW * fUU3 +
        hsConst.f3B201 * fWW3 * fV +
        hsConst.f3B021 * fUU3 * fV +
        hsConst.f3B102 * fW * fVV3 +
        hsConst.f3B012 * fU * fVV3 +
        hsConst.f3B111 * 6.0f * fW * fU * fV, 
        1.0);
    o.normalOS = normalize(
        i[0].normalOS * fWW +
        i[1].normalOS * fUU +
        i[2].normalOS * fVV +
        hsConst.f3N110 * fW * fU +
        hsConst.f3N011 * fU * fV +
        hsConst.f3N101 * fW * fV);
    o.tangentOS = float4(normalize(
        i[0].tangentOS.xyz * fWW +
        i[1].tangentOS.xyz * fUU +
        i[2].tangentOS.xyz * fVV +
        hsConst.f3N110 * fW * fU +
        hsConst.f3N011 * fU * fV +
        hsConst.f3N101 * fW * fV), 
        i[0].tangentOS.w);
    o.texcoord = 
        i[0].texcoord * fW + 
        i[1].texcoord * fU + 
        i[2].texcoord * fV;
    o.lightmapUV = 
        i[0].lightmapUV * fW + 
        i[1].lightmapUV * fU + 
        i[2].lightmapUV * fV;

    return o;
}

void AppendFinVertex(
    inout TriangleStream<Varyings> stream, 
    float2 uv, 
    float3 posOS, 
    float3 normalOS, 
    float4 tangentOS, 
    float2 finUv)
{
    Varyings output = (Varyings)0;

    VertexPositionInputs vertexInput = GetVertexPositionInputs(posOS);
    VertexNormalInputs normalInput = GetVertexNormalInputs(normalOS, tangentOS);
    output.positionCS = vertexInput.positionCS;
    output.positionWS = vertexInput.positionWS;
    output.normalWS = normalInput.normalWS;
    output.uv = uv;
    output.finUv = finUv;

    float3 vertexLight = VertexLighting(output.positionWS, normalInput.normalWS);
    float fogFactor = ComputeFogFactor(output.positionCS.z);
    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

    OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
    OUTPUT_SH(output.normalWS, output.vertexSH);

    stream.Append(output);
}

void AppendFinVertices(
    inout TriangleStream<Varyings> stream,
    Attributes input0,
    Attributes input1,
    Attributes input2,
    float3 normalOS)
{
    float3 posOS0 = input0.positionOS.xyz;
    float3 lineOS01 = input1.positionOS.xyz - posOS0;
    float3 lineOS02 = input2.positionOS.xyz - posOS0;
    float3 posOS3 = posOS0 + (lineOS01 + lineOS02) / 2;

    float2 uv0 = TRANSFORM_TEX(input0.texcoord, _BaseMap);
    float2 uv12 = (TRANSFORM_TEX(input1.texcoord, _BaseMap) + TRANSFORM_TEX(input2.texcoord, _BaseMap)) / 2;
    float uvOffset = length(uv0);
    float uvXScale = length(uv0 - uv12) * _Density;
    float4 tangentOS0 = input0.tangentOS;
    float4 tangentOS3 = input1.tangentOS;

    AppendFinVertex(stream, uv0, posOS0, normalOS, tangentOS0, float2(uvOffset, 0.0));
    AppendFinVertex(stream, uv12, posOS3, normalOS, tangentOS3, float2(uvOffset + uvXScale, 0.0));

    float3 normalWS = TransformObjectToWorldNormal(normalOS);
    float3 posWS = TransformObjectToWorld(posOS0);
    float finStep = _FinLength / _FinJointNum;
    float3 windAngle = _Time.w * _WindFreq.xyz;
    float3 windMoveWS = _WindMove.xyz * sin(windAngle + posWS * _WindMove.w);
    float3 baseMoveWS = _BaseMove.xyz;

    [loop] for (int i = 1; i <= _FinJointNum; ++i)
    {
        float finFactor = (float)i / _FinJointNum;
        float moveFactor = pow(abs(finFactor), _BaseMove.w);
        float3 moveWS = SafeNormalize(normalWS + (baseMoveWS + windMoveWS) * moveFactor) * finStep;
        float3 moveOS = TransformWorldToObjectDir(moveWS, false);
        posOS0 += moveOS;
        posOS3 += moveOS;
        AppendFinVertex(stream, uv0, posOS0, normalOS, tangentOS0, float2(uvOffset, finFactor));
        AppendFinVertex(stream, uv12, posOS3, normalOS, tangentOS3, float2(uvOffset + uvXScale, finFactor));
    }
    stream.RestartStrip();
}

[maxvertexcount(23)]
void geom(triangle Attributes input[3], inout TriangleStream<Varyings> stream)
{
#ifdef DRAW_ORIG_POLYGON
    for (int i = 0; i < 3; ++i)
    {
        Varyings output = (Varyings)0;

        VertexPositionInputs vertexInput = GetVertexPositionInputs(input[i].positionOS.xyz);
        VertexNormalInputs normalInput = GetVertexNormalInputs(input[i].normalOS, input[i].tangentOS);
        output.positionCS = vertexInput.positionCS;
        output.positionWS = vertexInput.positionWS;
        output.normalWS = normalInput.normalWS;
        output.uv = TRANSFORM_TEX(input[i].texcoord, _BaseMap);
        output.finUv = float2(-1.0, -1.0);

        float3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
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

    normalOS += rand3(input[0].texcoord) * _RandomDirection;
    normalOS = normalize(normalOS);

    AppendFinVertices(stream, input[0], input[1], input[2], normalOS);
}

float4 frag(Varyings input) : SV_Target
{
    float4 furColor = SAMPLE_TEXTURE2D(_FurMap, sampler_FurMap, input.finUv);
    if (input.finUv.x >= 0.0 && furColor.a < _AlphaCutout) discard;

    SurfaceData surfaceData = (SurfaceData)0;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);
    surfaceData.occlusion = lerp(1.0 - _Occlusion, 1.0, max(input.finUv.y, 0.0));

    InputData inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.normalWS = input.normalWS;
    inputData.viewDirectionWS = SafeNormalize(GetCameraPositionWS() - input.positionWS);
#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);

    float4 color = UniversalFragmentPBR(inputData, surfaceData);
    //ApplyRimLight(color.rgb, input.positionWS, viewDirWS, input.normalWS);
    color.rgb *= _BaseColor.rgb;
    color.rgb = MixFog(color.rgb, inputData.fogCoord);

    return color;
}

#endif
