Shader "Custom/GrassShaderURP"
{
	Properties
	{
		[Header(Tint Colors)]
		[Space]
		[MainColor] _Color("Tint Color",Color) = (0.5 ,0.5 ,0.5,1.0)
		_SelfShadowColor("Shadow Color",Color) = (0.41 ,0.41 ,0.36,1.0)
		_GrassSaturation("Grass Saturation", Float) = 2

		[Header(Textures)]
		[Space]
		[MainTexture]_MainTex("Color Grass", 2D) = "white" {}
		[NoScaleOffset]_GrassTex("Grass Pattern", 2D) = "white" {}
		[NoScaleOffset]_Noise("Noise Color", 2D) = "white" {}
		[NoScaleOffset]_Distortion("Distortion Wind", 2D) = "white" {}

		[Header(Geometry Values)]
		[Space]
		_MinimumNumberStacks("Min Displacement", Range(0, 17)) = 2
		_NumberOfStacks("Displacement", Range(0, 17)) = 12
		_OffsetValue("Offset Normal", Float) = 1
		_OffsetVector("Offset Vector", Vector) = (0,0,0)

		[Header(Grass Values)]
		[Space]
		_GrassThinness("Grass Thinness", Range(0.01, 2)) = 0.4
		_GrassThinnessIntersection("Grass Thinness Intersection", Range(0.01, 2)) = 0.43
		_TilingN1("Tiling Of Grass", Float) = 6.06
		_WindMovement("Wind Movement Speed", Float) = 0.55
		_WindForce("Wind Force", Float) = 0.35
		_TilingN3("Wind Noise Tiling", Float) = 1
		_NoisePower("Noise Power", Float) = 2
		_TilingN2("Tiling Of Noise Color", Float) = 0.05

		[Header(Level of Detail)]
		[Space]
		_FadeDistanceStart("LOD Fade-Distance Start", Float) = 16
		_FadeDistanceEnd("LOD Fade-Distance End", Float) = 26
	}
		SubShader
		{
			Tags{"DisableBatching" = "true" }
			pass
			{
			Tags{"RenderPipeline" = "UniversalPipeline" }
			LOD 100
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geom
			#pragma multi_compile_fog
			#pragma multi_compile_instancing
			#pragma prefer_hlslcc gles

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _SHADOWS_SOFT
			#pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
			#pragma multi_compile _ LIGHTMAP_ON

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2g
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float4 objPos : TEXCOORD1;
				float3 normal : TEXCOORD2;
				float4 shadowCoord : TEXCOORD4;
				float fogCoord : TEXCOORD5;
			};

			struct g2f
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float3 worldPos : TEXCOORD1;
				float2 color : COLOR;
				float3 normal : TEXCOORD2;
				float4 shadowCoord : TEXCOORD3;
				float fogCoord : TEXCOORD4;
			};
			// Render Texture Effects //
			uniform Texture2D _GlobalEffectRT;
			uniform float3 _Position;
			uniform float _OrthographicCamSize;
			uniform float _HasRT;


			int _NumberOfStacks, _MinimumNumberStacks;
			Texture2D _MainTex;
			Texture2D _NoGrassTex;
			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;

			Texture2D _Distortion;
			sampler2D _GrassTex;
			Texture2D _Noise;
			float _TilingN1;
			float _TilingN2, _WindForce;
			float4 _Color, _SelfShadowColor, _GroundColor;
			float4 _OffsetVector;
			float _TilingN3;
			float _WindMovement, _OffsetValue;
			half _GrassThinness, _GrassShading, _GrassThinnessIntersection;
			half _NoisePower, _GrassSaturation, _FadeDistanceStart, _FadeDistanceEnd;

			SamplerState my_linear_repeat_sampler;
			SamplerState my_linear_clamp_sampler;

			half _LightIntensity;

			float2 hash2D2D(float2 s)
			{
				//magic numbers
				return frac(sin(s) * 4.5453);
			}

			//stochastic sampling
			float4 tex2DStochastic(sampler2D tex, float2 UV)
			{
				float4x3 BW_vx;
				float2 skewUV = mul(float2x2 (1.0, 0.0, -0.57735027, 1.15470054), UV * 3.464);

				//vertex IDs and barycentric coords
				float2 vxID = float2 (floor(skewUV));
				float3 barry = float3 (frac(skewUV), 0);
				barry.z = 1.0 - barry.x - barry.y;

				BW_vx = ((barry.z > 0) ?
					float4x3(float3(vxID, 0), float3(vxID + float2(0, 1), 0), float3(vxID + float2(1, 0), 0), barry.zyx) :
					float4x3(float3(vxID + float2 (1, 1), 0), float3(vxID + float2 (1, 0), 0), float3(vxID + float2 (0, 1), 0), float3(-barry.z, 1.0 - barry.y, 1.0 - barry.x)));

				//calculate derivatives to avoid triangular grid artifacts
				float2 dx = ddx(UV);
				float2 dy = ddy(UV);

				//blend samples with calculated weights
				float4 stochasticTex = mul(tex2D(tex, UV + hash2D2D(BW_vx[0].xy), dx, dy), BW_vx[3].x) +
					mul(tex2D(tex, UV + hash2D2D(BW_vx[1].xy), dx, dy), BW_vx[3].y) +
					mul(tex2D(tex, UV + hash2D2D(BW_vx[2].xy), dx, dy), BW_vx[3].z);
				return stochasticTex;
			}

			v2g vert(appdata v)
			{
				v2g o;
				VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
				o.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);

				o.objPos = v.vertex;
				o.pos = GetVertexPositionInputs(v.vertex).positionCS;

				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.shadowCoord = GetShadowCoord(vertexInput);
				o.normal = v.normal;
				return o;
			}

			#define UnityObjectToWorld(o) mul(unity_ObjectToWorld, float4(o.xyz,1.0))
			[maxvertexcount(51)]
			void geom(triangle v2g input[3], inout TriangleStream<g2f> tristream)
			{
				g2f o;
				_OffsetValue *= 0.01;
				// Loop 3 times for the base ground geometry
				for (int i = 0; i < 3; i++)
				{
					o.uv = input[i].uv;
					o.pos = input[i].pos;
					o.color = 0.0;
					o.normal = GetVertexNormalInputs(input[i].normal).normalWS;
					o.worldPos = UnityObjectToWorld(input[i].objPos);
					o.shadowCoord = input[i].shadowCoord;
					o.fogCoord = ComputeFogFactor(input[i].pos.z);
					tristream.Append(o);
				}
				tristream.RestartStrip();

				float dist = distance(_WorldSpaceCameraPos, UnityObjectToWorld((input[0].objPos / 3 + input[1].objPos / 3 + input[2].objPos / 3)));
				if (dist > 0)
				{
					int NumStacks = lerp(_NumberOfStacks + 1, 0, (dist - _FadeDistanceStart) * (1 / max(_FadeDistanceEnd - _FadeDistanceStart, 0.0001)));//Clamp because people will start dividing by 0
					_NumberOfStacks = min(clamp(NumStacks, clamp(_MinimumNumberStacks, 0, _NumberOfStacks), 17), _NumberOfStacks);
				}

				float4 P; // P is shadow coords new position
				float4 objSpace; // objSpace is the vertex new position
				// Loop 3 times * numbersOfStacks for the grass
					for (float i = 1; i <= _NumberOfStacks; i++)
					{
						float4 offsetNormal = _OffsetVector * i * 0.01;
						for (int ii = 0; ii < 3; ii++)
						{
							P = input[ii].shadowCoord + _OffsetVector * _NumberOfStacks * 0.01;
							float4 NewNormal = float4(input[ii].normal,0); // problem is here

							objSpace = float4(input[ii].objPos + NewNormal * _OffsetValue * i + offsetNormal);

							o.color = (i / (_NumberOfStacks));
							o.uv = input[ii].uv;
							o.pos = GetVertexPositionInputs(objSpace).positionCS;
							o.shadowCoord = P;
							o.worldPos = UnityObjectToWorld(objSpace);
							o.normal = GetVertexNormalInputs(input[ii].normal).normalWS;
							o.fogCoord = ComputeFogFactor(input[ii].pos.z);
							tristream.Append(o);
						}
						tristream.RestartStrip();
					}
			}

			half4 frag(g2f i) : SV_Target
			{
							float2 mainUV;
			//Setup Coordinate Space
			mainUV = i.uv;
				float dist = 1;
				float2 uv = i.worldPos.xz - _Position.xz;
				uv = uv / (_OrthographicCamSize * 2);
				uv += 0.5;

				float bRipple = 1;

				float2 dis = _Distortion.Sample(my_linear_repeat_sampler, mainUV * _TilingN3 + _Time.xx * 3 * _WindMovement);
				float displacementStrengh = 0.6 * (((sin(_Time.y + dis * 5) + sin(_Time.y * 0.5 + 1.051)) / 5.0) + 0.15 * dis) * bRipple; //hmm math
				dis = dis * displacementStrengh * (i.color.r * 1.3) * _WindForce * bRipple;


				float ripples = 0.25;
				float ripples2 = 0;
				float ripples3 = 0;
				float3 normalDir = i.normal;
				float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
				float3 grassPattern = tex2D(_GrassTex, mainUV * _TilingN1 + dis.xy);
				half4 col = _MainTex.Sample(my_linear_repeat_sampler, mainUV + dis.xy * 0.09);

				float3 noise = _Noise.Sample(my_linear_repeat_sampler, mainUV * _TilingN2 + dis.xy) * _NoisePower;

				half alpha = step(1 - ((col.x + col.y + col.z + grassPattern.x) * _GrassThinness) * ((2 - i.color.r) * grassPattern.x) * saturate(ripples + 1) * saturate(ripples + 1), ((1 - i.color.r) * (ripples + 1)) * (grassPattern.x) * _GrassThinness - dis.x * 5);
				alpha = lerp(alpha, alpha + (grassPattern.x * (1 - i.color.r)) * _GrassThinnessIntersection, 1 * (ripples + 0.75));

				if (i.color.r >= 0.01)
				{
					if (alpha * (ripples3 + 1) - (i.color.r) < -0.02)discard;
				}
				_Color *= 2;

				col.xyz = (pow(abs(col), _GrassSaturation) * _GrassSaturation) * float3(_Color.x, _Color.y, _Color.z);
				col.xyz *= saturate(lerp(_SelfShadowColor, 1, pow(abs(i.color.x), 1.1)) + (_GrassShading * (ripples * 1 + 1) - noise.x * dis.x * 2) + (1 - grassPattern.r) - noise.x * dis.x * 2);
				col.xyz *= _Color * (ripples * -0.1 + 1);
				col.xyz *= 1 - (ripples2 * (1 - saturate(i.color.r - 0.7)));


				float4 shadowCoord;
				half3 lm = 1;

				// Additional light pass in URP, thank you Unity for this //
				int additionalLightsCount = GetAdditionalLightsCount();
				for (int ii = 0; ii < additionalLightsCount; ++ii)
				{
					Light light = GetAdditionalLight(ii, i.worldPos);
					col.xyz += (light.color * light.distanceAttenuation * light.distanceAttenuation) * (_LightIntensity * 0.5);
				}
				col.xyz = MixFog(col.xyz, i.fogCoord);

				return col;
			}
				ENDHLSL
		}
		UsePass "Universal Render Pipeline/Lit/ShadowCaster"

		}
}
