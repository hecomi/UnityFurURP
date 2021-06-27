Shader "Unlit/Fur"
{

Properties
{
    _BaseMap("Base Map", 2D) = "white" {}
    _FurMap("Fur Map", 2D) = "white" {}
    [IntRange] _ShellAmount("Shell Amount", Range(1, 42)) = 16
    _ShellStep("Shell Step", Range(0.0, 0.01)) = 0.001
    _AlphaCutout("Alpha Cutout", Range(0.0, 1.0)) = 0.2
    _FurScale("Fur Scale", Range(0.0, 10.0)) = 1.0
    _Occlusion("Occlusion", Range(0.0, 1.0)) = 0.5
    _BaseMove("Base Move", Vector) = (0.0, -0.0, 0.0, 3.0)
    _WindFreq("Wind Freq", Vector) = (0.5, 0.7, 0.9, 1.0)
    _WindMove("Wind Move", Vector) = (0.2, 0.3, 0.2, 1.0)
}

SubShader
{
    Tags 
    { 
        "RenderType" = "Opaque" 
        "RenderPipeline" = "UniversalPipeline" 
        "IgnoreProjector" = "True"
    }

    LOD 100

    ZWrite On
    Cull Back

    Pass
    {
        Name "Unlit"
        HLSLPROGRAM
        #pragma exclude_renderers gles gles3 glcore
        #pragma multi_compile_fog
        #include "./FurUnlit.hlsl"
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom 
        #pragma fragment frag
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
        #include "./FurDepth.hlsl"
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom 
        #pragma fragment frag
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
        #pragma exclude_renderers gles gles3 glcore
        #include "./FurShadow.hlsl"
        #pragma vertex vert
        #pragma require geometry
        #pragma geometry geom 
        #pragma fragment frag
        ENDHLSL
    }
}

}
