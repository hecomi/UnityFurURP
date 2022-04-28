Shader "Fur/Shell/Lit"
{

Properties
{
    [Header(Basic)][Space]
    [MainColor] _BaseColor("Color", Color) = (0.5, 0.5, 0.5, 1)
    _AmbientColor("Ambient Color", Color) = (0.0, 0.0, 0.0, 1)
    _BaseMap("Albedo", 2D) = "white" {}
    [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.5
    _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5

    [Header(Reduce Flickering)][Space]
    [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 0.0

    [Header(Fur)][Space]
    [NoScaleOffset]_FurMap("Fur", 2D) = "white" {}
    [NoScaleOffset][Normal] _NormalMap("Normal", 2D) = "bump" {}
    _NormalScale("Normal Scale", Range(0.0, 2.0)) = 1.0
    [IntRange] _ShellAmount("Shell Amount", Range(1, 52)) = 13
    [Header(More Shell Amount)][Space]
    [Toggle(_GEOM_INSTANCING)] _GeomInstancing("Enable", Float) = 0
    [HideInInspector] _ShellStep("Shell Step", Range(0.0, 0.02)) = 0.001
    [Space][Space] _TotalShellStep("Total Shell Step", Range(0.0, 0.25)) = 0.026
    _AlphaCutout("Alpha Cutout", Range(0.0, 1.0)) = 0.2
    _FurScale("Fur Scale", Range(0.0, 10.0)) = 1.0
    _Occlusion("Occlusion", Range(0.0, 1.0)) = 0.5
    [NoScaleOffset] _FurLengthMap("Fur Length Map", 2D) = "white" {}
    _FurLengthIntensity("Fur Length Intensity", Range(0.0, 5.0)) = 1.0
    _BaseMove("Base Move", Vector) = (0.0, -0.0, 0.0, 3.0)
    _WindFreq("Wind Freq", Vector) = (0.5, 0.7, 0.9, 1.0)
    _WindMove("Wind Move", Vector) = (0.2, 0.3, 0.2, 1.0)

    [Header(Lighting)]
    [Header(Rim Light)][Space]
    _RimLightPower("Rim Light Power", Range(1.0, 20.0)) = 6.0
    _RimLightIntensity("Rim Light Intensity", Range(0.0, 1.0)) = 0.5

    [Header(Marschner Scatter)][Space]
    [Toggle(_FUR_SPECULAR)] _FurSpecular("Enable", Float) = 0
    _Backlit("Backlit", Range(0.0, 1.0)) = 0.5
    _Area("Lit Area", Range(0.01, 1.0)) = 0.1
    _MedulaScatter("Fur Scatter", Range(0.01, 1.0)) = 1.0
    _MedulaAbsorb("Fur Absorb", Range(0.01, 1.0)) = 0.1
    _Kappa("Kappa", Range(0.0, 2.0)) = 1.0

    [Header(Shadow)][Space]
    _ShadowExtraBias("Shadow Extra Bias", Range(-1.0, 1.0)) = 0.0
    [Toggle(_NO_FUR_SHADOW)] _NoFurShadow("Mesh Shadow Only", Float) = 0
    
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

    LOD 100

    ZWrite On
    ZTest LEqual
    Cull Back

    Pass
    {
        Name "ForwardLit"
        Tags { "LightMode" = "UniversalForward" }

        ZWrite On

        HLSLPROGRAM
        // URP のキーワード
#if (UNITY_VERSION >= 202111)
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        #pragma multi_compile_fragment _ _LIGHT_LAYERS
#else
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#endif
        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile _ _SHADOWS_SOFT
        #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
        #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
        #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
        //#pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF

        #pragma multi_compile_fragment _ _FUR_SPECULAR
        #pragma multi_compile _ _GEOM_INSTANCING

        // Unity のキーワード
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED
        #pragma multi_compile _ LIGHTMAP_ON
        #pragma multi_compile_fog
        #pragma multi_compile_instancing
        #pragma multi_compile _ DOTS_INSTANCING_ON

        #pragma prefer_hlslcc gles
        #pragma exclude_renderers d3d11_9x
        // if "_GEOM_INSTANCING", then Microsoft ShaderModel 4.1 (geometry shader instancing support)
        // It is "target 4.6" in Unity. (Tested on OpenGL 4.1, instancing not supported on OpenGL 4.0)
        #pragma target 4.6 _GEOM_INSTANCING
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #include "./Lit.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "DepthOnly"
        Tags { "LightMode" = "DepthOnly" }

        ZWrite On
        ColorMask 0

        HLSLPROGRAM
        #pragma multi_compile _ _GEOM_INSTANCING

        #pragma exclude_renderers gles
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #pragma target 4.6 _GEOM_INSTANCING
        #include "./Depth.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "DepthNormals"
        Tags { "LightMode" = "DepthNormals" }

        ZWrite On

        HLSLPROGRAM
        #pragma multi_compile _ _GEOM_INSTANCING

        #pragma exclude_renderers gles
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #pragma target 4.6 _GEOM_INSTANCING
        #include "./DepthNormals.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "ShadowCaster"
        Tags { "LightMode" = "ShadowCaster" }

        ZWrite On
        ZTest LEqual
        ColorMask 0

        HLSLPROGRAM
        #pragma multi_compile _ _GEOM_INSTANCING
        #pragma multi_compile _ _NO_FUR_SHADOW

        #pragma exclude_renderers gles
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #pragma target 4.6 _GEOM_INSTANCING
        #include "./Shadow.hlsl"
        ENDHLSL
    }

//---------------------------For Microsoft Shader Model < 4.1---------------------------------------------
//-----------------------Geometry Shader Instancing not supported.----------------------------------------
    Pass
    {
        Name "ForwardLit"
        Tags { "LightMode" = "UniversalForward" }

        ZWrite On

        HLSLPROGRAM
        // URP のキーワード
#if (UNITY_VERSION >= 202111)
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        #pragma multi_compile_fragment _ _LIGHT_LAYERS
#else
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#endif
        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile _ _SHADOWS_SOFT
        #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
        #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
        #pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
        //#pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF

        #pragma multi_compile_fragment _ _FUR_SPECULAR

        // Unity のキーワード
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED
        #pragma multi_compile _ LIGHTMAP_ON
        #pragma multi_compile_fog
        #pragma multi_compile_instancing
        #pragma multi_compile _ DOTS_INSTANCING_ON

        #pragma prefer_hlslcc gles
        #pragma exclude_renderers d3d11_9x
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #include "./Lit.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "DepthOnly"
        Tags { "LightMode" = "DepthOnly" }

        ZWrite On
        ColorMask 0

        HLSLPROGRAM
        #pragma multi_compile _ _GEOM_INSTANCING

        #pragma exclude_renderers gles
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #include "./Depth.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "DepthNormals"
        Tags { "LightMode" = "DepthNormals" }

        ZWrite On

        HLSLPROGRAM
        #pragma multi_compile _ _GEOM_INSTANCING

        #pragma exclude_renderers gles
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #include "./DepthNormals.hlsl"
        ENDHLSL
    }

    Pass
    {
        Name "ShadowCaster"
        Tags { "LightMode" = "ShadowCaster" }

        ZWrite On
        ZTest LEqual
        ColorMask 0

        HLSLPROGRAM
        #pragma multi_compile _ _NO_FUR_SHADOW

        #pragma exclude_renderers gles
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom
        #pragma fragment frag
        #include "./Shadow.hlsl"
        ENDHLSL
    }
}
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
