#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

#include "AutoLight.cginc"
#include "UnityPBSLighting.cginc"

//在属性说明的参数需要在Pass中声明才能使用
float4 _Tint;
sampler2D _MainTex, _DetailTex;
float4 _MainTex_ST, _DetailTex_ST;//用于设置偏移和缩放，ST是Scale和Transform的意思

sampler2D _MetallicMap;
float _Metallic;
float _Smoothness;

sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;

sampler2D _EmissionMap;
float3 _Emission;


//顶点数据结构
struct VertexData {
    float4 vertex : POSITION;//POSITION表示对象本地坐标
    float3 normal : NORMAL;//获取法线信息
    float4 tangent : TANGENT;//获取切线信息
    float2 uv : TEXCOORD0;//纹理坐标
};

//插值后数据结构
struct Interpolators {
    float4 pos : SV_POSITION;//SV_POSITION语义告诉unity,pos里包含了顶点在裁剪空间中的位置信息
    float4 uv : TEXCOORD0;//纹理坐标，这里用xy作为主要纹理，zw作为细节纹理，法线贴图同理
    float3 normal : TEXCOORD1;

    #if defined(BINORMAL_PER_FRAGMENT)//用于获取切线空间
        float4 tangent : TEXCOORD2;
    #else
        float3 tangent : TEXCOORD2;
        float3 binormal : TEXCOORD3;
    #endif

    float3 worldPos : TEXCOORD4;//物体的世界坐标，用来获取视方向

    SHADOW_COORDS(5)

    #if defined(VERTEXLIGHT_ON)//顶点光
        float3 vertexLightColor : TEXCOORD6;
    #endif
};

//计算顶点光颜色
void ComputeVertexLightColor (inout Interpolators i) {
    #if defined(VERTEXLIGHT_ON)
        i.vertexLightColor = Shade4PointLights(
			unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
			unity_LightColor[0].rgb, unity_LightColor[1].rgb,
			unity_LightColor[2].rgb, unity_LightColor[3].rgb,
			unity_4LightAtten0, i.worldPos, i.normal
		);
    #endif
}

float3 CreateBinormal (float3 normal, float3 tangent, float binormalSign) {
	return cross(normal, tangent.xyz) * (binormalSign * unity_WorldTransformParams.w);
}

//顶点数据通过顶点程序后进行插值，插值后数据传递给片元程序
Interpolators MyVertexProgram(VertexData v) {
    Interpolators i;
    i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
    i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
    i.pos = UnityObjectToClipPos(v.vertex);
    i.normal = UnityObjectToWorldNormal(v.normal);//得到法线的世界坐标

    #if defined(BINORMAL_PER_FRAGMENT)
        i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
    #else
        i.tangent = UnityObjectToWorldDir(v.tangent);
        i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
    #endif

    i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
    i.worldPos = mul(unity_ObjectToWorld, v.vertex);

    TRANSFER_SHADOW(i);//这两个有先后顺序，不然会报错
    ComputeVertexLightColor(i);

    return i;
}

float GetMetallic (Interpolators i) {
	#if defined(_METALLIC_MAP)
		return tex2D(_MetallicMap, i.uv.xy).r;
	#else
		return _Metallic;
	#endif
}

float GetSmoothness (Interpolators i) {
	float smoothness = 1;
	#if defined(_SMOOTHNESS_ALBEDO)
		smoothness = tex2D(_MainTex, i.uv.xy).a;
	#elif defined(_SMOOTHNESS_METALLIC) && defined(_METALLIC_MAP)
		smoothness = tex2D(_MetallicMap, i.uv.xy).a;
	#endif
	return smoothness * _Smoothness;
}

float3 GetEmission (Interpolators i) {
	#if defined(FORWARD_BASE_PASS)
		#if defined(_EMISSION_MAP)
			return tex2D(_EmissionMap, i.uv.xy) * _Emission;
		#else
			return _Emission;
		#endif
	#else
		return 0;
	#endif
}

UnityLight CreateLight (Interpolators i) {//创建直接光结构，最后渲染结果要用
    UnityLight light;

    #if defined(POINT) || defined(SPOT) //有点光源和聚光灯的情况
        light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
    #else
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif

    UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
    light.color = _LightColor0 * attenuation;
    light.ndotl = DotClamped(i.normal, light.dir);
    return light;
}

float3 BoxProjection (
	float3 direction, float3 position,
	float4 cubemapPosition, float3 boxMin, float3 boxMax
) {//反射探针盒
    #if UNITY_SPECCUBE_BOX_PROJECTION
        UNITY_BRANCH
        if (cubemapPosition.w > 0) {
            float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
            float scalar = min(min(factors.x, factors.y), factors.z);
            direction = direction * scalar + (position - cubemapPosition);
        }
    #endif
	return direction;
}

UnityIndirect CreateIndirectLight (Interpolators i, float3 viewDir) {//创建间接光结构，最后渲染结果要用
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;

    #if defined(VERTEXLIGHT_ON)//有顶点光的话可以把顶点光视为环境光
        indirectLight.diffuse = i.vertexLightColor;
    #endif

    #if defined(FORWARD_BASE_PASS)//反射相关
		indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
        float3 reflectionDir = reflect(-viewDir, i.normal);

        /*以下用的大部分都是unity的自带的宏，包括反射探针的混合*/
        Unity_GlossyEnvironmentData envData;
		envData.roughness = 1 - GetSmoothness(i);
		envData.reflUVW = BoxProjection(
			reflectionDir, i.worldPos,
			unity_SpecCube0_ProbePosition,
			unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
		);
		float3 probe0 = Unity_GlossyEnvironment(
			UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
		);
        envData.reflUVW = BoxProjection(
			reflectionDir, i.worldPos,
			unity_SpecCube1_ProbePosition,
			unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
		);

        #if UNITY_SPECCUBE_BLENDING
            float interpolator = unity_SpecCube0_BoxMin.w;
            UNITY_BRANCH
            if (interpolator < 0.99999) {
                float3 probe1 = Unity_GlossyEnvironment(
                    UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0),
                    unity_SpecCube0_HDR, envData
                );
                indirectLight.specular = lerp(probe1, probe0, interpolator);
            }
            else {
                indirectLight.specular = probe0;
            }
        #else
            indirectLight.specular = probe0;
        #endif
	#endif


    return indirectLight;
}

//法线贴图相关
void InitializeFragmentNormal(inout Interpolators i) {
    float3 mainNormal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
    float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
    float3 tangentSpaceNormal = BlendNormals(mainNormal, detailNormal);

    #if defined(BINORMAL_PER_FRAGMENT)
        float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
    #else
        float3 binormal = i.binormal;
    #endif

    i.normal = normalize(
		tangentSpaceNormal.x * i.tangent +
		tangentSpaceNormal.y * binormal +
		tangentSpaceNormal.z * i.normal
    );
}

//片元程序
float4 MyFragmentProgram(Interpolators i) : SV_TARGET{
    InitializeFragmentNormal(i);

    float3 lightDir = _WorldSpaceLightPos0.xyz;
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

    float3 lightColor = _LightColor0.xyz;
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
    albedo *= tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;

    //以下是金属工作流程
    float3 specularTint;
    float oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic(
        albedo, GetMetallic(i), specularTint, oneMinusReflectivity
    );

    //以下是基于物理着色的输出，从金属工作流程升级
    float4 color = UNITY_BRDF_PBS(
        albedo, specularTint,
        oneMinusReflectivity, GetSmoothness(i),
        i.normal, viewDir,
        CreateLight(i), CreateIndirectLight(i, viewDir)
    );
    color.rgb += GetEmission(i);
	return color;
}
#endif