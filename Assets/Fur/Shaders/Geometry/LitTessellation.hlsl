#ifndef FUR_FIN_LIT_TESSELLATION_HLSL
#define FUR_FIN_LIT_TESSELLATION_HLSL

#include "./Param.hlsl"

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
    o.texcoord = 
        i[0].texcoord * fW + 
        i[1].texcoord * fU + 
        i[2].texcoord * fV;
    o.lightmapUV = 
        i[0].lightmapUV * fW + 
        i[1].lightmapUV * fU + 
        i[2].lightmapUV * fV;
    o.id = i[0].id;

    return o;
}

#endif
