using ImpliciX.Language;
using ImpliciX.Language.GUI;
using ImpliciX.Language.Model;
using ImpliciX.Language.StdLib;
using ImpliciX.Language.Store;
using TimeZone = ImpliciX.Language.Model.TimeZone;

namespace Corkscrew.App;

public class Main : ApplicationDefinition
{
  public Main()
  {
    AppName = "Corkscrew";
    AppSettingsFile = "appsettings.json";

    DataModelDefinition = new DataModelDefinition()
    {
      Assembly = device._.GetType().Assembly,
      AppVersion = device._.software.version.measure,
      AppEnvironment = device._.environment,
      GlobalProperties = new (Urn, object)[]
      {
        (device._.timezone, TimeZone.Europe__Paris)
      }
    };

    ModuleDefinitions = new object[]
    {
      new UserInterfaceModuleDefinition { UserInterface = Gui.Definition },
      new PersistentStoreModuleDefinition { CleanVersionSettings = device._._clean_version_settings },
      ModuleDefinition.SystemSoftware(device._, _ => true),
      ModuleDefinition.MmiHost(device._),
    };
  }
}