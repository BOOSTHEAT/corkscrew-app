
using Corkscrew.App;
using ImpliciX.Linker;

var outputFolder = Path.Combine(Path.GetTempPath(), nameof(Corkscrew) + Path.GetRandomFileName());
Qml.Generate(new Main(), outputFolder);
