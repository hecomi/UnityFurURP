#ifndef FUR_SHELL_PARAM_HLSL
#define FUR_SHELL_PARAM_HLSL

int _ShellAmount;
float _ShellStep;
float _AlphaCutout;
float _Occlusion;
float _FurScale;
float4 _BaseMove;
float4 _WindFreq;
float4 _WindMove;
float3 _AmbientColor;
float _FaceViewProdThresh;

TEXTURE2D(_FurMap); 
SAMPLER(sampler_FurMap);
float4 _FurMap_ST;

TEXTURE2D(_NormalMap); 
SAMPLER(sampler_NormalMap);
float4 _NormalMap_ST;
float _NormalScale;

TEXTURE2D(_FurLengthMap);
SAMPLER(sampler_FurLengthMap);
float _FurLengthIntensity;

float _Backlit;
float _Area;
float _MedulaScatter;
float _MedulaAbsorb;
float _Kappa;
#endif