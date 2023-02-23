// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/ManyLightShader"
{
    Properties//属性面板，用来说明参数属性
    {
        _Tint ("Color", Color) = (1, 1, 1, 1)
        _MainTex ("Albedo", 2D) = "white"{}

        //_SpecularTint ("SpecularColor", Color) = (1, 1, 1, 1) //如果是金属工作流程则不需要高光颜色
        [NoScaleOffset] _NormalMap ("Normals", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Range(0, 1)) = 0.25

        [NoScaleOffset] _MetallicMap ("Metallic", 2D) = "white" {}
        [Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 1

        _DetailTex ("Detail Albedo", 2D) = "gray" {}
        [NoScaleOffset] _DetailNormalMap ("Detail Normals", 2D) = "bump" {}
		_DetailBumpScale ("Detail Bump Scale", Range(0, 1)) = 1

        [NoScaleOffset] _EmissionMap ("Emission", 2D) = "black" {}
		_Emission ("Emission", Color) = (0, 0, 0)

    }

    CGINCLUDE

	#define BINORMAL_PER_FRAGMENT

	ENDCG
    
    SubShader
    {
        Pass//基础灯光通道
        {
            Tags{
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM

            #pragma target 3.0

            #pragma shader_feature _METALLIC_MAP//调用金属度贴图
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC//不同的平滑度贴图采样方式
            #pragma shader_feature _EMISSION_MAP//调用自发光贴图

            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ VERTEXLIGHT_ON//启用顶点灯

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #define FORWARD_BASE_PASS

            #include "My Lighting.cginc"

            ENDCG
        }

        Pass//其他灯光
        {
            Tags{
                "LightMode" = "ForwardAdd"
            }

            Blend One One
            Zwrite Off

            CGPROGRAM

            #pragma target 3.0

            #pragma shader_feature _METALLIC_MAP
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC

            #pragma multi_compile_fwdadd_fullshadows

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #include "My Lighting.cginc"

            ENDCG
        }

        Pass//启动阴影
        {
            Tags{
                "LightMode" = "ShadowCaster"
            }

            CGPROGRAM

            #pragma target 3.0

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #include "My shadows.cginc"

            ENDCG
        }
    }

    CustomEditor "MyLightingShaderGUI"//这个要放在最后面
}