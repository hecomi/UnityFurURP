#ifndef FUR_GEOMETRY_PARAM_HLSL
#define FUR_GEOMETRY_PARAM_HLSL

float4 _AmbientColor;
float _FurLength;
int _FurJoint;
float _Occlusion;
float _RandomDirection;
float _NormalFactor;

float4 _BaseMove;
float4 _WindFreq;
float4 _WindMove;

float _TessMinDist;
float _TessMaxDist;
float _TessFactor;

float _MoveScale;
float _Spring;
float _Damper;
float _Gravity;

#endif