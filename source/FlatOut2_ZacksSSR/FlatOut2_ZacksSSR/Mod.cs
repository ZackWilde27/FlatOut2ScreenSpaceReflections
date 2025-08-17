using FlatOut2.SDK;
using FlatOut2.SDK.API;
using FlatOut2.SDK.Enums;
using FlatOut2_ZacksSSR.Configuration;
using FlatOut2_ZacksSSR.Template;
using Microsoft.VisualBasic;
using Reloaded.Hooks.Definitions.X86;
using Reloaded.Hooks.ReloadedII.Interfaces;
using Reloaded.Mod.Interfaces;
using System.Reflection.Metadata;
using System.Runtime.InteropServices;
using static Reloaded.Hooks.Definitions.X86.FunctionAttribute;

namespace FlatOut2_ZacksSSR
{
    /// <summary>
    /// Your mod logic goes here.
    /// </summary>
    public unsafe class Mod : ModBase // <= Do not Remove.
    {
        /// <summary>
        /// Provides access to the mod loader API.
        /// </summary>
        private readonly IModLoader _modLoader;

        /// <summary>
        /// Provides access to the Reloaded.Hooks API.
        /// </summary>
        /// <remarks>This is null if you remove dependency on Reloaded.SharedLib.Hooks in your mod.</remarks>
        private readonly IReloadedHooks? _hooks;

        /// <summary>
        /// Provides access to the Reloaded logger.
        /// </summary>
        private static ILogger _logger;

        /// <summary>
        /// Entry point into the mod, instance that created this class.
        /// </summary>
        private readonly IMod _owner;

        /// <summary>
        /// Provides access to this mod's configuration.
        /// </summary>
        private Config _configuration;

        /// <summary>
        /// The configuration of the currently executing mod.
        /// </summary>
        private readonly IModConfig _modConfig;

        private struct FO2Shader(void* shader, string filename)
        {
            public void* Shader = shader;
            public string Filename = filename;
            public DateTime LastModified = new(0);
            public string Handle = "";
        }

        private static readonly FO2Shader[] Shaders = new FO2Shader[50];
        private static int ShaderCount;

        [DllImport("SSR.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Ansi)]
        private static extern void UpdateTextures(void* shader, string handle);

        [DllImport("SSR.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Ansi)]
        private static extern void GetBackBuffer();

        // The shader swapping re-uses the DLL from my shader swapper
        [DllImport("dxStuff.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Ansi)]
        private static unsafe extern void RecompileShader(void* shaderPtr, string shader, uint shaderLen);
 

        [DllImport("SSR.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Ansi)]
        private static extern void CreateTextures();

        [DllImport("SSR.dll", CallingConvention = CallingConvention.StdCall, CharSet = CharSet.Ansi)]
        private static extern bool TextureExists(void* shader, string handle);

        [Function([Register.eax, Register.esi], Register.eax, StackCleanup.Callee)]
        [UnmanagedFunctionPointer(CallingConvention.StdCall, CharSet = CharSet.Ansi)]
        private delegate void* Shader_ShaderPtr(void* effect_EAX, void* shader_ESI, string filename, int param_2);

        private static Reloaded.Hooks.Definitions.IHook<Shader_ShaderPtr> ShaderShaderHook;

        static readonly string[] Filenames = ["pro_car_body.sha"];

        private static void* NewShader_Shader(void* effect_EAX, void* shader_ESI, string filename, int param_2)
        {
            void* val = ShaderShaderHook.OriginalFunction(effect_EAX, shader_ESI, filename, param_2);

            foreach (var item in Filenames)
            {
                if (filename.EndsWith(item))
                {
                    Shaders[ShaderCount] = new(shader_ESI, filename);
                    int i = 0;
                    while (TextureExists(effect_EAX, "Tex" + i.ToString()))
                        i++;

                    // This decrement will need to be commented out if the shader swapping feature is re-enabled
                    i--;
                    Shaders[ShaderCount].Handle = "Tex" + i.ToString();
                    _logger.WriteLine(filename + ", " + Shaders[ShaderCount++].Handle);
                    break;
                }
            }


            return val;
        }

        private static void PerFrame()
        {
            //CheckShaderRecomp();

            GetBackBuffer();
            for (int i = 0; i < ShaderCount; i++)
                UpdateTextures(Shaders[i].Shader, Shaders[i].Handle);
        }

        // I implemented the shader swapper into this mod for developing the shaders
        private static void CheckShaderRecomp()
        {
            for (int i = 0; i < ShaderCount; i++)
            {
                DateTime dateModified;
                try
                {
                    dateModified = FileSystem.FileDateTime(Shaders[i].Filename);
                }
                catch (Exception e)
                {
                    return;
                }

                if (dateModified > Shaders[i].LastModified)
                {
                    string shaderText = "";
                    // Race conditions
                    try
                    {
                        shaderText = File.ReadAllText(Shaders[i].Filename);
                    }
                    catch (Exception e)
                    {
                        return;
                    }

                    RecompileShader(Shaders[i].Shader, shaderText, (uint)shaderText.Length);
                    Shaders[i].LastModified = dateModified;
                }
            }
        }

        public Mod(ModContext context)
        {
            _modLoader = context.ModLoader;
            _hooks = context.Hooks;
            _logger = context.Logger;
            _owner = context.Owner;
            _configuration = context.Configuration;
            _modConfig = context.ModConfig;


            // For more information about this template, please see
            // https://reloaded-project.github.io/Reloaded-II/ModTemplate/

            // If you want to implement e.g. unload support in your mod,
            // and some other neat features, override the methods in ModBase.

            // TODO: Implement some mod logic

            SDK.Init(_hooks!);
            Helpers.HookPerFrame(PerFrame);

            ShaderShaderHook = _hooks!.CreateHook<Shader_ShaderPtr>(NewShader_Shader, 0x005ACBD0).Activate();
        }

        #region Standard Overrides
        public override void ConfigurationUpdated(Config configuration)
        {
            // Apply settings from configuration.
            // ... your code here.
            _configuration = configuration;
            _logger.WriteLine($"[{_modConfig.ModId}] Config Updated: Applying");
        }
        #endregion

        #region For Exports, Serialization etc.
#pragma warning disable CS8618 // Non-nullable field must contain a non-null value when exiting constructor. Consider declaring as nullable.
        public Mod() { }
#pragma warning restore CS8618
        #endregion
    }
}