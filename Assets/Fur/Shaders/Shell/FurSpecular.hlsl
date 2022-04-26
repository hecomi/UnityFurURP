#ifndef FUR_SPECULAR_HLSL
#define FUR_SPECULAR_HLSL

//-------------------------------------------------------------------------------------------------
// Fur shading from "maajor"'s https://github.com/maajor/Marschner-Hair-Unity, licensed under MIT.
//-------------------------------------------------------------------------------------------------

struct SurfaceOutputFur
// Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
//#pragma exclude_renderers d3d11 gles
{
	half3 Albedo;
	half MedulaScatter;
	half MedulaAbsorb;
	half3 Normal;//Tangent actually
	half3 VNormal;//vertext normal
	half3 Emission;
	half Alpha;
	half Roughness;
	half Specular;
	half Layer;
	half Kappa;
};

inline float square(float x) {
	return x * x;
}

float acosFast(float inX)
{
	float x = abs(inX);
	float res = -0.156583f * x + (0.5 * PI);
	res *= sqrt(1.0f - x);
	return (inX >= 0) ? res : PI - res;
}

#define SQRT2PI 2.50663

//Gaussian Distribution for M term
inline float Hair_G(float B, float Theta)
{
	return exp(-0.5 * square(Theta) / (B*B)) / (SQRT2PI * B);
}


inline float3 SpecularFresnel(float3 F0, float vDotH) {
	return F0 + (1.0f - F0) * pow(1 - vDotH, 5);
}

inline float3 SpecularFresnelLayer(float3 F0, float vDotH, float layer) {
	float3 fresnel = SpecularFresnel(F0,  vDotH);
    return (fresnel * layer) / (1 + (layer-1) * fresnel);
}

// Yan, Ling-Qi, etc, "An efficient and practical near and far field fur reflectance model."
float3 FurBSDFYan(SurfaceOutputFur s, float3 L, float3 V, float3 N, float Shadow, float Backlit, float Area)
{
	float3 S = 0;

	const float VoL = dot(V, L);
	const float SinThetaL = dot(N, L);
	const float SinThetaV = dot(N, V);
	float cosThetaL = sqrt(max(0, 1 - SinThetaL * SinThetaL));
	float cosThetaV = sqrt(max(0, 1 - SinThetaV * SinThetaV));
	float CosThetaD = sqrt((1 + cosThetaL * cosThetaV + SinThetaV * SinThetaL) / 2.0);

	const float3 Lp = L - SinThetaL * N;
	const float3 Vp = V - SinThetaV * N;
	const float CosPhi = dot(Lp, Vp) * rsqrt(dot(Lp, Lp) * dot(Vp, Vp) + 1e-4);
	const float CosHalfPhi = sqrt(saturate(0.5 + 0.5 * CosPhi));

	float n_prime = 1.19 / CosThetaD + 0.36 * CosThetaD;

	float Shift = 0.0499f;
	float Alpha[] =
	{
		-0.0998,//-Shift * 2,
		0.0499f,// Shift,
		0.1996  // Shift * 4
	};
	float B[] =
	{
		Area + square(s.Roughness),
		Area + square(s.Roughness) / 2,
		Area + square(s.Roughness) * 2
	};

	//float F0 = square((1 - 1.55f) / (1 + 1.55f));
	float F0 = 0.04652;//eta=1.55f

	float3 Tp;
	float Mp, Np, Fp, a, h, f;
	float ThetaH = SinThetaL + SinThetaV;
	// R
	Mp = Hair_G(B[0], ThetaH - Alpha[0]);
	Np = 0.25 * CosHalfPhi;
	Fp = SpecularFresnelLayer(F0, sqrt(saturate(0.5 + 0.5 * VoL)), s.Layer).x;
	S += (Mp * Np) * (Fp * lerp(1, Backlit, saturate(-VoL)));

	// TT
	Mp = Hair_G(B[1], ThetaH - Alpha[1]);
	a = rcp(n_prime);
	h = CosHalfPhi * (1 + a * (0.6 - 0.8 * CosPhi));
	f = SpecularFresnelLayer(F0, CosThetaD * sqrt(saturate(1 - h * h)), s.Layer).x;
	Fp = square(1 - f);
	float sinGammaTSqr = square((h * a));
	float sm = sqrt(saturate(square(s.Kappa)-sinGammaTSqr));
	float sc = sqrt(1 - sinGammaTSqr) - sm;
	Tp = pow(s.Albedo, 0.5 * sc / CosThetaD) * pow(s.MedulaAbsorb*s.MedulaScatter, 0.5 * sm / CosThetaD);
	Np = exp(-3.65 * CosPhi - 3.98);
	S += (Mp * Np) * (Fp * Tp) * Backlit;

	// TRT
	Mp = Hair_G(B[2], ThetaH - Alpha[2]);
	f = SpecularFresnelLayer(F0, CosThetaD * 0.5f, s.Layer).x;
	Fp = square(1 - f) * f;
	// assume h = sqrt(3)/2, calculate sm and sc
	sm = sqrt(saturate(square(s.Kappa)-0.75f));
	sc = 0.5f - sm;
	Tp = pow(s.Albedo, sc / CosThetaD) * pow(s.MedulaAbsorb*s.MedulaScatter, sm / CosThetaD);
	Np = exp((6.3f*CosThetaD+0.7f)*CosPhi-(5*CosThetaD+2));

	S += (Mp * Np) * (Fp * Tp);

	// TTs
	// hacking approximate Cm
	Mp = abs(cosThetaL)*0.5f;
	// still assume h = sqrt(3)/2
	Tp = pow(s.Albedo, (sc+1-s.Kappa)/(4*CosThetaD)) * pow(s.MedulaAbsorb, s.Kappa / (4*CosThetaD));
	// hacking approximate pre-integrated Dtts based on Cn
	Np = 0.05*(2*CosPhi*CosPhi - 1) + 0.16f;//0.05*std::cos(2*Phi) + 0.16f;

	S += (Mp * Np) * (f * Tp);

	//TRTs
	float phi = acosFast(CosPhi);
	// hacking approximate pre-integrated Dtrts based on Cn
	Np = 0.05f * cos(1.5*phi+1.7) + 0.18f;
	// still assume h = sqrt(3)/2
	Tp = pow(s.Albedo, (3*sc+1-s.Kappa)/(4*CosThetaD)) * pow(s.MedulaAbsorb, (2*sm+s.Kappa) / (4*CosThetaD)) * pow(s.MedulaScatter, sm/(8*CosThetaD));
	Fp = f * (1-f);

	S += (Mp * Np) * (Fp * Tp);

	return S;
}

float3 FurDiffuseKajiya(SurfaceOutputFur s, float3 L, float3 V, float3 N, half Shadow, float Backlit, float Area) {
	float3 S = 0;
	float KajiyaDiffuse = 1 - abs(dot(N, L));

	float3 FakeNormal = SafeNormalize(V - N * dot(V, N));
	N = FakeNormal;

	// Hack approximation for multiple scattering.
	float Wrap = 1;
	float NoL = saturate((dot(N, L) + Wrap) / square(1 + Wrap));
	float DiffuseScatter = (1 / PI) * lerp(NoL, KajiyaDiffuse, 0.33);// *s.Metallic;
	float Luma = Luminance(s.Albedo);
	float3 ScatterTint = pow(s.Albedo / Luma, 1 - Shadow);
	S = sqrt(s.Albedo) * DiffuseScatter * ScatterTint;
	return S;
}

float3 FurBxDF(SurfaceOutputFur s, float3 N, half3 V, half3 L, float Shadow, float Backlit, float Area)
{
	float3 S = float3(0, 0, 0);

	S = FurBSDFYan(s, L, V, N, Shadow, Backlit, Area);
	S += FurDiffuseKajiya(s, L, V, N, Shadow, Backlit, Area);

	S = -min(-S, 0.0);

	return S;
}

#endif