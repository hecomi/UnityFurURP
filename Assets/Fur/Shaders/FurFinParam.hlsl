#ifndef FUR_FIN_PARAM_HLSL
#define FUR_FIN_PARAM_HLSL

float4 _AmbientColor;
float _FaceViewProdThresh;
float _FinLength;
float _AlphaCutout;
float _Occlusion;
float _Density;
float _RandomDirection;
float4 _BaseMove;
float4 _WindFreq;
float4 _WindMove;
int _FinJointNum;
float _NormalScale;
float _FaceNormalFactor;

float _TessMinDist;
float _TessMaxDist;
float _TessFactor;

TEXTURE2D(_FurMap); 
SAMPLER(sampler_FurMap);
float4 _FurMap_ST;

TEXTURE2D(_NormalMap); 
SAMPLER(sampler_NormalMap);
float4 _NormalMap_ST;

#endif