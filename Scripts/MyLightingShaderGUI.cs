using UnityEngine;
using UnityEditor;

public class MyLightingShaderGUI : ShaderGUI 
{
	Material target;
    MaterialEditor editor;
	MaterialProperty[] properties;
    static GUIContent staticLabel = new GUIContent();
	enum SmoothnessSource {
		Uniform, Albedo, Metallic
	}
	static ColorPickerHDRConfig emissionConfig =
		new ColorPickerHDRConfig(0f, 99f, 1f / 99f, 3f);

	bool IsKeywordEnabled (string keyword) {
		return target.IsKeywordEnabled(keyword);
	}

	void RecordAction (string label) {
		editor.RegisterPropertyChangeUndo(label);
	}

    public override void OnGUI(MaterialEditor editor, MaterialProperty[] properties) {
		this.target = editor.target as Material;
        this.editor = editor;
		this.properties = properties;
        DoMain();
        DoSecondary();
    }

    MaterialProperty FindProperty (string name) {//用一个便捷的方法来调用着色器的参数
		return FindProperty(name, properties);
	}

	static GUIContent MakeLabel (string text, string tooltip = null) {//一个便捷设置GUIContent Label的方法
		staticLabel.text = text;
		staticLabel.tooltip = tooltip;
		return staticLabel;
	}

    static GUIContent MakeLabel (MaterialProperty property, string tooltip = null) {//（重载）一个便捷设置GUIContent Label的方法
		staticLabel.text = property.displayName;
		staticLabel.tooltip = tooltip;
		return staticLabel;
	}

	void SetKeyword (string keyword, bool state) {
		if (state) {
			target.EnableKeyword(keyword);
		}
		else {
			target.DisableKeyword(keyword);
		}
	}

	//一层菜单
    void DoMain() {
        GUILayout.Label("Main Maps", EditorStyles.boldLabel);//设置标签，用粗体

        MaterialProperty mainTex = FindProperty("_MainTex");//调用着色器中的主要纹理参数
        editor.TexturePropertySingleLine(MakeLabel(mainTex, "Albedo (RGB)"), mainTex, FindProperty("_Tint"));//在UI中显示参数，单行
        DoMetallic();
		DoSmoothness();
        DoNormals();
		DoEmission();
        editor.TextureScaleOffsetProperty(mainTex);
    }

	//法线相关
    void DoNormals () {
		MaterialProperty map = FindProperty("_NormalMap");
		editor.TexturePropertySingleLine(
            MakeLabel(map), map,
            map.textureValue ? FindProperty("_BumpScale") : null);//如果没有使用材质，则隐藏Bumping值
	}

	//金属度相关
    void DoMetallic () {
		MaterialProperty map = FindProperty("_MetallicMap");
		EditorGUI.BeginChangeCheck();
		editor.TexturePropertySingleLine(
            MakeLabel(map, "Metallic (R)"), map,
            map.textureValue ? null : FindProperty("_Metallic")//如果使用了金属贴图，则隐藏统一值
        );
		if (EditorGUI.EndChangeCheck()) {
			SetKeyword("_METALLIC_MAP", map.textureValue);
		}
	}

	//平滑度相关
	void DoSmoothness () {
		SmoothnessSource source = SmoothnessSource.Uniform;
		if (IsKeywordEnabled("_SMOOTHNESS_ALBEDO")) {
			source = SmoothnessSource.Albedo;
		}
		else if (IsKeywordEnabled("_SMOOTHNESS_METALLIC")) {
			source = SmoothnessSource.Metallic;
		}

		MaterialProperty slider = FindProperty("_Smoothness");
		EditorGUI.indentLevel += 2;
		editor.ShaderProperty(slider, MakeLabel(slider));
		EditorGUI.indentLevel += 1;
		EditorGUI.BeginChangeCheck();
		source = (SmoothnessSource)EditorGUILayout.EnumPopup(MakeLabel("Source"), source);
		if (EditorGUI.EndChangeCheck()) {
			RecordAction("Smoothness Source");
			SetKeyword("_SMOOTHNESS_ALBEDO", source == SmoothnessSource.Albedo);
			SetKeyword(
				"_SMOOTHNESS_METALLIC", source == SmoothnessSource.Metallic
			);
		}
		EditorGUI.indentLevel -= 3;
	}

	void DoEmission () {
		MaterialProperty map = FindProperty("_EmissionMap");
		EditorGUI.BeginChangeCheck();
		editor.TexturePropertyWithHDRColor(
			MakeLabel(map, "Emission (RGB)"), map, FindProperty("_Emission"), emissionConfig, false
		);
		if (EditorGUI.EndChangeCheck()) {
			SetKeyword("_EMISSION_MAP", map.textureValue);
		}
	}

	//二层菜单
    void DoSecondary () {
		GUILayout.Label("Secondary Maps", EditorStyles.boldLabel);

		MaterialProperty detailTex = FindProperty("_DetailTex");
		editor.TexturePropertySingleLine(
			MakeLabel(detailTex, "Albedo (RGB) multiplied by 2"), detailTex
		);
        DoSecondaryNormals();
		editor.TextureScaleOffsetProperty(detailTex);
	}

	//二层菜单法线（细节法线
    void DoSecondaryNormals () {
		MaterialProperty map = FindProperty("_DetailNormalMap");
		editor.TexturePropertySingleLine(
			MakeLabel(map), map,
			map.textureValue ? FindProperty("_DetailBumpScale") : null
		);
	}
}