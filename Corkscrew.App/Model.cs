using ImpliciX.Language.GUI;
using ImpliciX.Language.StdLib;

namespace Corkscrew.App;

public class device : Device
{
  public static device _ = new ();

  private device() : base(nameof(device))
  {
    main_screen = new GuiNode(this, nameof(main_screen));
    startup_screen = new GuiNode(this, nameof(startup_screen));
  }
  
  public GuiNode main_screen { get; }
  public GuiNode startup_screen { get; }
}