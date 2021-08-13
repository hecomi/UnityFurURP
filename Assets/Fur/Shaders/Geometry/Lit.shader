Shader "Fur/Geometry/Lit"
{

Properties
{
    [Header(Basic)][Space]
    [MainColor] _BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1)
    _AmbientColor("AmbientColor", Color) = (0.0, 0.0, 0.0, 1)
    _BaseMap("Base Map", 2D) = "white" {}
    [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.5
    _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5

    [Header(Fur)][Space]
    _FurLength("Fur Length", Range(0.0, 2.0)) = 0.3
    [IntRange] _FurJoint("Fur Joint", Range(0, 6)) = 3
    _Occlusion("Occlusion", Range(0.0, 1.0)) = 0.3
    _RandomDirection("Random Direction", Range(0.0, 1.0)) = 0.3
    _NormalFactor("Normal Factor", Range(0.0, 1.0)) = 0.0

    [Header(Move)][Space]
    _BaseMove("Base Move", Vector) = (0.0, -0.0, 0.0, 3.0)
    _WindFreq("Wind Freq", Vector) = (0.5, 0.7, 0.9, 1.0)
    _WindMove("Wind Move", Vector) = (0.2, 0.3, 0.2, 1.0)

    [Header(Tesselation)][Space]
    _TessMinDist("Tesselation Min Distance", Range(0.1, 10)) = 1.0
    _TessMaxDist("Tesselation Max Distance", Range(0.1, 100)) = 10.0
    _TessFactor("Tessellation Factor", Range(1, 10)) = 4 

    [Header(Lighting)][Space]
    _RimLightPower("Rim Light Power", Range(1.0, 20.0)) = 6.0
    _RimLightIntensity("Rim Light Intensity", Range(0.0, 1.0)) = 0.5
    _ShadowExtraBias("Shadow Extra Bias", Range(-1.0, 1.0)) = 0.0

    [Header(Move)][Space]
    _MoveScale("MoveScale", Range(0.0, 5.0)) = 1.0
    _Spring("Spring", Range(0.0, 20.0)) = 5.0
    _Damper("Damper", Range(0.0, 10.0)) = 1.0
    _Gravity("Gravity", Range(-10.0, 10.0)) = -2.0
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
    Cull Back

    Pass
    {
        Name "ForwardLit"
        Tags { "LightMode" = "UniversalForward" }

        ZWrite On
        Cull Back

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

        #pragma target 5.0
        #pragma exclude_renderers gles gles3 glcore
        #pragma multi_compile _ DRAW_ORIG_POLYGON
        #pragma vertex vert
        #pragma require tessellation tessHW
        #pragma hull hull
        #pragma domain domain
        #pragma require geometry
        #pragma geometry geom 
        #pragma fragment frag
        #include "./Lit.hlsl"
        #include "./LitTessellation.hlsl"
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
        #include "./Shadow.hlsl"
        #include "./UnlitTessellation.hlsl"
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
        #include "./Shadow.hlsl"
        #include "./UnlitTessellation.hlsl"
        ENDHLSL
    }
}

}
