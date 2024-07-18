using System.Drawing;
using System.Reflection;
using ImpliciX.Language.GUI;
using ImpliciX.Language.Model;

namespace Corkscrew.App;

public class Gui : Screens
{
  public static GUI Definition() =>
    GUI
      .Assets(Assembly.GetExecutingAssembly())
      .Locale(device._.locale)
      .StartWith(device._.main_screen)
      .Screen(device._.main_screen, new[]
      {
        At.Top(20).Left(20).Put(Column.Spacing(5).Layout(
          Row.Layout(Label("Serial Number: ").With(TextFont), Show(device._.serial_number).With(TextFont)),
          Row.Layout(Label("Corkscrew Release: ").With(TextFont),
            Show(device._.software.version.measure).With(TextFont)),
          Row.Layout(Label("BSP current slot: ").With(TextFont),
            Show(device._.bsp.software_version.measure).With(TextFont)),
          Row.Layout(Label("BSP other slot: ").With(TextFont),
            Show(device._.bsp.fallback_version.measure).With(TextFont)),
          Row.Layout(Label("Environment: ").With(TextFont), Show(device._.environment).With(TextFont)),
          Row.Layout(Label("Global Update State: ").With(TextFont),
            Show(device._.software.update_state).With(TextFont)),
          DeviceData("APP", device._.app),
          DeviceData("GUI", device._.gui),
          DeviceData("BSP", device._.bsp))),
        At.Top(20).Right(20).Put(Column.Spacing(5).Layout(
          Now.Date.With(TextFont),
          Now.HoursMinutesSeconds.With(TextFont)
        )),
        At.Right(20).Bottom(20).Put(
          Background(Box.Width(100).Height(50).Fill(Color.Gray)).Layout(
            At.HorizontalCenterOffset(0).VerticalCenterOffset(0).Put(Label("REBOOT").With(Font.ExtraBold.Size(20)))
          ).Send(device._._reboot).NavigateTo(device._.startup_screen, Label("")))
      })
      .Screen(device._.startup_screen, new[]
      {
        At.HorizontalCenterOffset(0).VerticalCenterOffset(-75)
          .Put(Label("Please Wait...").With(Font.ExtraBold.Size(64))),
        At.HorizontalCenterOffset(0).VerticalCenterOffset(75).Put(Image("Assets/loading.gif")),
      })
      .WhenNotConnected(device._.startup_screen);

  private static Block DeviceData(string name, SoftwareDeviceNode sdn) =>
    Row.Layout(Label($"{name} Update Progress: ").With(TextFont),
      Show(sdn.update_progress).With(TextFont));

  public static Font TextFont = Font.ExtraBold.Size(16);
}