Shader "Fur/Geometry/Unlit"
{

Properties
{
    [Header(Basic)][Space]
    [MainColor] _BaseColor("Color", Color) = (0.5, 0.5, 0.5, 1)
    _BaseMap("Base Map", 2D) = "white" {}

    [Header(Fur)][Space]
    _FurLength("Fur Length", Range(0.0, 2.0)) = 0.3
    [IntRange] _FurJoint("Fur Joint", Range(0, 6)) = 3
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
}

SubShader
{
    Tags 
    { 
        "RenderType" = "Opaque" 
        "RenderPipeline" = "UniversalPipeline" 
        "IgnoreProjector" = "True"
    }

    ZWrite On
    Cull Back

    Pass
    {
        Name "Unlit"

        HLSLPROGRAM
        #pragma exclude_renderers gles gles3 glcore
        #pragma multi_compile_fog
        #pragma vertex vert
        #pragma require tessellation tessHW
        #pragma hull hull
        #pragma domain domain
        #pragma require geometry
        #pragma geometry geom 
        #pragma fragment frag
        #include "./Unlit.hlsl"
        #include "./UnlitTessellation.hlsl"
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
