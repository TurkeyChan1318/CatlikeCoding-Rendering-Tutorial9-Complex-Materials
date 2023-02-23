// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/FirstLightShader"
{
    Properties//属性面板，用来说明参数属性
    {
        _Tint ("Color", Color) = (1, 1, 1, 1)
        _MainTex ("Albedo", 2D) = "white"{}
        //_SpecularTint ("SpecularColor", Color) = (1, 1, 1, 1) //如果是金属工作流程则不需要高光颜色
        [Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 1

    }
    SubShader
    {
        Pass
        {
            Tags{
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM

            #pragma target 3.0

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #include "UnityPBSLighting.cginc"

            //在属性说明的参数需要在Pass中声明才能使用
            float4 _Tint;
            sampler2D _MainTex; 
            float4 _MainTex_ST;//用于设置偏移和缩放，ST是Scale和Transform的意思
            //float4 _SpecularTint; //如果是金属工作流程则不需要高光颜色
            float _Metallic;
            float _Smoothness;

            //顶点数据结构
            struct VertexData {
                float4 position : POSITION;//POSITION表示对象本地坐标
                float3 normal : NORMAL;//获取法线信息
                float2 uv : TEXCOORD0;//纹理坐标
            };

            //插值后数据结构
            struct Interpolators {
				float4 position : SV_POSITION;//SV_POSITION指系统的坐标，反正就是要加个语义进去才能使用
                float3 normal : NORMAL;
				float2 uv : TEXCOORD0;//纹理坐标
                float3 worldPos : TEXCOORD1;//物体的世界坐标，用来获取视方向
			};

            //顶点数据通过顶点程序后进行插值，插值后数据传递给片元程序
            Interpolators MyVertexProgram (VertexData v) {
				Interpolators i;
				i.uv = TRANSFORM_TEX(v.uv, _MainTex);
				i.position = UnityObjectToClipPos(v.position);
                i.normal = UnityObjectToWorldNormal(v.normal);//得到法线的世界坐标
                i.worldPos = mul(unity_ObjectToWorld, v.position);
				return i;
			}

            //片元程序
			float4 MyFragmentProgram (Interpolators i) : SV_TARGET {
                i.normal = normalize(i.normal);//在片元程序归一化，避免使用顶点数据

                float3 lightDir = _WorldSpaceLightPos0.xyz;
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                //float3 halfDir = normalize(lightDir + viewDir);//如果是使用PBS，则不需要这行

                float3 lightColor = _LightColor0.xyz;
                // float3 specularTint;
                float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;
                // float oneMinusReflectivity;
                // albedo = EnergyConservationBetweenDiffuseAndSpecular(
				// 	albedo, _SpecularTint.rgb, oneMinusReflectivity
				// );//使光照强度保持恒定，漫反射 + 镜面高光 = 总光照强度, 这个是常用做法

                //以下是金属工作流程
                float3 specularTint;
                float oneMinusReflectivity;
                albedo = DiffuseAndSpecularFromMetallic(
					albedo, _Metallic, specularTint, oneMinusReflectivity
				);

                //漫反射输出
                //float3 diffuse = albedo * lightColor * DotClamped(lightDir, i.normal);
                //高光输出
                //float3 specular = _SpecularTint.rgb * lightColor * pow(DotClamped(halfDir, i.normal), _Smoothness * 100);

                //下面这行代码是金属工作流程的高光输出
                //float3 specular = specularTint * lightColor * pow(DotClamped(halfDir, i.normal), _Smoothness * 100);

				//return float4(diffuse + specular, 1);

                //以下是基于物理着色的输出，从金属工作流程升级，使用时不需要上方的diffuse和specular
                UnityLight light;//直接光结构
				light.color = lightColor;
				light.dir = lightDir;
				light.ndotl = DotClamped(i.normal, lightDir);
				UnityIndirect indirectLight;//间接光结构
				indirectLight.diffuse = 0;
				indirectLight.specular = 0;

				return UNITY_BRDF_PBS(
					albedo, specularTint,
					oneMinusReflectivity, _Smoothness,
					i.normal, viewDir,
					light, indirectLight
				);
			}

            ENDCG
        }
    }
}