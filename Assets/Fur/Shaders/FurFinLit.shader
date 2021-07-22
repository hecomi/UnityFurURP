Shader "Fur/Fin/Lit"
{

Properties
{
    [Header(Basic)][Space]
    [MainColor] _BaseColor("Color", Color) = (0.5, 0.5, 0.5, 1)
    _BaseMap("Base Map", 2D) = "white" {}
    [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.5
    _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5

    [Header(Fur)][Space]
    [Toggle(DRAW_ORIG_POLYGON)]_DrawOrigPolygon("Draw Original Polygon", Float) = 1
    [NoScaleOffset] _FurMap("Fur Map", 2D) = "white" {}
    [IntRange] _FinJointNum("Fin Joint Num", Range(1, 10)) = 5
    _AlphaCutout("Alpha Cutout", Range(0.0, 1.0)) = 0.2
    _FinLength("Length", Range(0.0, 1.0)) = 0.1
    _Density("Density", Range(0.1, 10.0)) = 1.0
    _FaceViewProdThresh("Direction Threshold", Range(0.0, 1.0)) = 0.1
    _Occlusion("Occlusion", Range(0.0, 1.0)) = 0.3
    _RandomDirection("Random Direction", Range(0.0, 1.0)) = 0.3

    [Header(Move)][Space]
    _BaseMove("Base Move", Vector) = (0.0, -0.0, 0.0, 3.0)
    _WindFreq("Wind Freq", Vector) = (0.5, 0.7, 0.9, 1.0)
    _WindMove("Wind Move", Vector) = (0.2, 0.3, 0.2, 1.0)

    [Header(Tesselation)][Space]
    _TessMinDist("Tesselation Min Distance", Range(0.1, 50)) = 1.0
    _TessMaxDist("Tesselation Max Distance", Range(0.1, 50)) = 10.0
    _TessFactor("Tessellation Factor", Range(1, 50)) = 10

    [Header(Lighting)][Space]
    _ShadowExtraBias("Shadow Extra Bias", Range(-1.0, 1.0)) = 0.0
}

SubShader
{
    Tags 
    { 
        "RenderType" = "Opaque" 
        "RenderPipeline" = "UniversalPipeline" 
        "UniversalMaterialType" = "Lit"
        "IgnoreProjector" = "True"
    }

    ZWrite On
    Cull Off

    Pass
    {
        Name "ForwardLit"
        Tags { "LightMode" = "UniversalForward" }

        HLSLPROGRAM
        // URP
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile _ _SHADOWS_SOFT
        #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

        // Unity
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED
        #pragma multi_compile _ LIGHTMAP_ON
        #pragma multi_compile_fog

        #pragma exclude_renderers gles gles3 glcore
        #pragma multi_compile _ DRAW_ORIG_POLYGON
        #pragma vertex vert
        #pragma require tessellation tessHW
        #pragma hull hull
        #pragma domain domain
        #pragma require geometry
        #pragma geometry geom 
        #pragma fragment frag
        #include "./FurFinLit.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "DepthOnly"
        Tags { "LightMode" = "DepthOnly" }

        ZWrite On
        ColorMask 0

        HLSLPROGRAM
        #pragma exclude_renderers gles gles3 glcore
        #pragma multi_compile_fog
        #pragma multi_compile _ DRAW_ORIG_POLYGON
        #pragma multi_compile _ APPEND_MORE_FINS
        #pragma vertex vert
        #pragma require tessellation tessHW
        #pragma hull hull
        #pragma domain domain
        #pragma require geometry
        #pragma geometry geom 
        #pragma fragment frag
        #include "./FurFinShadow.hlsl"
        #include "./FurFinUnlitTessellation.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "ShadowCaster"
        Tags {"LightMode" = "ShadowCaster" }

        ZWrite On
        ZTest LEqual
        ColorMask 0

        HLSLPROGRAM
        #pragma exclude_renderers gles gles3 glcore
        #pragma multi_compile_fog
        #pragma multi_compile _ DRAW_ORIG_POLYGON
        #pragma multi_compile _ APPEND_MORE_FINS
        #pragma vertex vert
        #pragma require tessellation tessHW
        #pragma hull hull
        #pragma domain domain
        #pragma require geometry
        #pragma geometry geom 
        #pragma fragment frag
        #define SHADOW_CASTER_PASS
        #include "./FurFinShadow.hlsl"
        #include "./FurFinUnlitTessellation.hlsl"
        ENDHLSL
    }
}

}
