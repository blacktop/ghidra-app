#!/bin/sh

set -eu

create_iconset() {
	mkdir -p Ghidra.iconset
	cat << EOF > Ghidra.iconset/Contents.json
{
	"images":
	[
		{
			"filename": "icon_16x16.png",
			"idiom": "mac",
			"scale": "1x",
			"size": "16x16"
		},
		{
			"filename": "icon_32x32.png",
			"idiom": "mac",
			"scale": "2x",
			"size": "16x16"
		},
		{
			"filename": "icon_32x32.png",
			"idiom": "mac",
			"scale": "1x",
			"size": "32x32"
		},
		{
			"filename": "icon_64x64.png",
			"idiom": "mac",
			"scale": "2x",
			"size": "32x32"
		},
		{
			"filename": "icon_128x128.png",
			"idiom": "mac",
			"size": "128x128",
			"scale": "1x"
		},
		{
			"filename": "icon_256x256.png",
			"idiom": "mac",
			"scale": "2x",
			"size": "128x128"
		},
		{
			"filename": "icon_256x256.png",
			"idiom": "mac",
			"scale": "1x",
			"size": "256x256"
		},
		{
			"filename": "icon_512x512.png",
			"idiom": "mac",
			"scale": "2x",
			"size": "256x256"
		},
		{
			"filename": "icon_512x512.png",
			"idiom": "mac",
			"scale": "1x",
			"size": "512x512"
		},
		{
			"filename": "icon_1024x1024.png",
			"idiom": "mac",
			"scale": "2x",
			"size": "512x512"
		}
	],
	"info":
	{
		"version": 1,
		"author": "xcode"
	}
}
EOF
	for size in 16 32 64 128 256 512 1024; do
		convert "$1" -resize "${size}x${size}" "Ghidra.iconset/icon_${size}x${size}.png"
	done
}

if [ $# -ne 1 ]; then
	echo "Usage: $0 [path to ghidra folder]" >&2
	exit 1
fi

mkdir -p Ghidra.app/Contents/MacOS
cat << EOF | clang -x objective-c -fmodules -framework Foundation -o Ghidra.app/Contents/MacOS/Ghidra -
@import Foundation;

int main() {
	execl([NSBundle.mainBundle.resourcePath stringByAppendingString:@"/ghidra/ghidraRun"].UTF8String, NULL);
}
EOF
mkdir -p Ghidra.app/Contents/Resources/
rm -rf Ghidra.app/Contents/Resources/ghidra
cp -R "$(echo "$1" | sed s,/*$,,)" Ghidra.app/Contents/Resources/ghidra
sed "s/bg Ghidra/fg Ghidra/" < "$1/ghidraRun" > Ghidra.app/Contents/Resources/ghidra/ghidraRun
sed "s/apple.laf.useScreenMenuBar=false/apple.laf.useScreenMenuBar=true/" < "$1/support/launch.properties" > Ghidra.app/Contents/Resources/ghidra/support/launch.properties
echo "APPL????" > Ghidra.app/Contents/PkgInfo
jar -x -f Ghidra.app/Contents/Resources/ghidra/Ghidra/Framework/Gui/lib/Gui.jar images/GhidraIcon256.png
if [ "$( (sw_vers -productVersion; echo "11.0") | sort -V | head -n 1)" = "11.0" ]; then
	convert \( -size 1024x1024 canvas:none -fill white -draw 'roundRectangle 100,100 924,924 180,180' \) \( +clone -background black -shadow 25x12+0+12 \) +swap -background none -layers flatten -crop 1024x1024+0+0 \( images/GhidraIcon256.png -resize 704x704 -gravity center \) -composite GhidraIcon.png
else
	mv images/GhidraIcon256.png GhidraIcon.png
fi
create_iconset GhidraIcon.png
for size in 16 24 32 40 48 64 128 256; do
	convert GhidraIcon.png -resize "${size}x${size}" "images/GhidraIcon${size}.png"
	jar -u -f Ghidra.app/Contents/Resources/ghidra/Ghidra/Framework/Generic/lib/Generic.jar "images/GhidraIcon${size}.png"
done

iconutil -c icns Ghidra.iconset
cp Ghidra.icns Ghidra.app/Contents/Resources
SetFile -a B Ghidra.app
cat << EOF > Ghidra.app/Contents/Info.plist
<?xml version="1.0" ?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>CFBundleDevelopmentRegion</key>
		<string>English</string>
		<key>CFBundleExecutable</key>
		<string>Ghidra</string>
		<key>CFBundleIconFile</key>
		<string>Ghidra.icns</string>
		<key>CFBundleIdentifier</key>
		<string>org.ghidra-sre.Ghidra</string>
		<key>CFBundleDisplayName</key>
		<string>Ghidra</string>
		<key>CFBundleInfoDictionaryVersion</key>
		<string>6.0</string>
		<key>CFBundleName</key>
		<string>Ghidra</string>
		<key>CFBundlePackageType</key>
		<string>APPL</string>
		<key>CFBundleShortVersionString</key>
		<string>$(grep application.version < "$1/Ghidra/application.properties" | sed "s/application.version=//")</string>
		<key>CFBundleVersion</key>
		<string>$(grep application.version < "$1/Ghidra/application.properties" | sed "s/application.version=//" | sed "s/\.//g")</string>
		<key>CFBundleSignature</key>
		<string>????</string>
		<key>NSHumanReadableCopyright</key>
		<string></string>
		<key>NSHighResolutionCapable</key>
		<true/>
	</dict>
</plist>
EOF

mkdir -p docking/widgets/filechooser/
cat << EOF > docking/widgets/filechooser/GhidraFileChooser.java
package docking.widgets.filechooser;

import docking.DialogComponentProvider;
import ghidra.util.filechooser.GhidraFileChooserModel;
import ghidra.util.filechooser.GhidraFileFilter;
import java.awt.Component;
import java.awt.Dialog;
import java.awt.FileDialog;
import java.io.File;
import java.io.FilenameFilter;
import java.util.Arrays;
import java.util.List;
import javax.swing.JFrame;
import javax.swing.SwingUtilities;

public class GhidraFileChooser extends DialogComponentProvider {
	private GhidraFileChooserModel model;
	private GhidraFileFilter filter;
	private FileDialog fileDialog;
	private int mode = FILES_AND_DIRECTORIES;

	public static final int FILES_ONLY = 0;
	public static final int DIRECTORIES_ONLY = 1;
	public static final int FILES_AND_DIRECTORIES = 2;

	public GhidraFileChooser(Component parent) {
		this(new LocalFileChooserModel(), parent);
	}

	GhidraFileChooser(GhidraFileChooserModel model, Component parent) {
		super("File Chooser", true, true, true, false);
		this.model = model;
		Component root = SwingUtilities.getRoot(parent);
		if (root instanceof Dialog) {
			fileDialog = new FileDialog((Dialog)root);
		} else {
			fileDialog = new FileDialog((JFrame)root);
		}
	}

	public void setShowDetails(boolean showDetails) {
	}

	public void setFileSelectionMode(int mode) {
		this.mode = mode;
	}

	public void setFileSelectionMode(GhidraFileChooserMode mode) {
		switch (mode) {
		case FILES_ONLY:
			this.mode = 0;
			break;
		case DIRECTORIES_ONLY:
			this.mode = 1;
			break;
		case FILES_AND_DIRECTORIES:
			this.mode = 2;
			break;
		}
	}

	public boolean isMultiSelectionEnabled() {
		return fileDialog.isMultipleMode();
	}

	public void setMultiSelectionEnabled(boolean b) {
		fileDialog.setMultipleMode(b);
	}

	public void setApproveButtonText(String buttonText) {
	}

	public void setApproveButtonToolTipText(String tooltipText) {
	}

	public File getSelectedFile() {
		show();
		String path = fileDialog.getFile();
		return path != null ? new File(fileDialog.getDirectory(), path) : null;
	}

	public List<File> getSelectedFiles() {
		show();
		return Arrays.asList(fileDialog.getFiles());
	}

	public File getSelectedFile(boolean show) {
		return getSelectedFile();
	}

	public void setSelectedFile(File file) {
		fileDialog.setFile(file != null ? file.getPath() : null);
	}

	public void show() {
		fileDialog.setVisible(true);
	}

	public void close() {
		fileDialog.setVisible(false);
	}

	public File getCurrentDirectory() {
		return new File(fileDialog.getDirectory());
	}

	public void setCurrentDirectory(File directory) {
		fileDialog.setDirectory(directory.getPath());
	}

	public void rescanCurrentDirectory() {
	}

	private class _FilenameFilter implements FilenameFilter {
		@Override
		public boolean accept(File dir, String name) {
			File file = new File(dir, name);
			switch (mode) {
			case DIRECTORIES_ONLY:
				if (file.isFile()) {
					return false;
				}
				break;
			case FILES_AND_DIRECTORIES:
			default:
				break;
			}
			return filter.accept(file, model);
		}
	}

	public void addFileFilter(GhidraFileFilter f) {
	}

	public void setSelectedFileFilter(GhidraFileFilter filter) {
		this.filter = filter;
	}

	public void setFileFilter(GhidraFileFilter filter) {
		this.filter = filter;
	}

	public boolean wasCancelled() {
		return fileDialog.getFile() == null;
	}

	@Override
	public void setTitle(String title) {
		fileDialog.setTitle(title);
	}
}
EOF

javac -cp "$(find Ghidra.app -regex '.*\.jar' | tr '\n' ':')" docking/widgets/filechooser/GhidraFileChooser.java
cp -R docking Ghidra.app/Contents/Resources/Ghidra/ghidra/patch/

cat << EOF > OpenGhidra.java
import com.sun.tools.attach.VirtualMachine;
import com.sun.tools.attach.VirtualMachineDescriptor;
import java.io.File;

public class OpenGhidra {
	public static void main(String[] args) throws Exception {
		Runtime.getRuntime().exec(new String[] {"open", "-a", "Ghidra"});
		while (true) {
			for (VirtualMachineDescriptor descriptor : VirtualMachine.list()) {
				if (descriptor.displayName().contains("ghidra.Ghidra")) {
					VirtualMachine vm = VirtualMachine.attach(descriptor.id());
					for (String arg : args) {
						vm.loadAgent(OpenGhidra.class.getProtectionDomain().getCodeSource().getLocation().getPath() + "/OpenGhidra.jar", new File(arg).getAbsolutePath());
					}
					vm.detach();
					return;
				}
			}
		}
	}
}
EOF
javac OpenGhidra.java
cp OpenGhidra.class Ghidra.app/Contents/Resources
cat << EOF > OpenGhidraAgent.java
import ghidra.app.services.ProgramManager;
import ghidra.formats.gfilesystem.FileSystemService;
import ghidra.framework.main.AppInfo;
import ghidra.plugin.importer.ImporterUtilities;
import java.awt.Frame;
import java.awt.Menu;
import java.awt.MenuItem;
import java.io.File;
import java.util.Timer;
import java.util.TimerTask;

public class OpenGhidraAgent {
	private static boolean checkMenuForReadiness(MenuItem menuItem) {
		if (menuItem.getLabel().contains("Import File") && menuItem.isEnabled()) {
			return true;
		} else if (menuItem instanceof Menu) {
			var menu = (Menu)menuItem;
			for (int i = 0; i < menu.getItemCount(); ++i) {
				if (checkMenuForReadiness(menu.getItem(i))) {
					return true;
				}
			}
		}
		return false;
	}

	public static void agentmain(String agentArgs) {
		Timer timer = new Timer();
		timer.schedule(new TimerTask() {
			@Override
			public void run() {
				for (var frame : Frame.getFrames()) {
					var menuBar = frame.getMenuBar();
					if (menuBar == null) {
						continue;
					}
					for (int i = 0; i < menuBar.getMenuCount(); ++i) {
						if (checkMenuForReadiness(menuBar.getMenu(i))) {
							var file = new File(agentArgs);
							var tool = AppInfo.getFrontEndTool();
							var manager = tool.getService(ProgramManager.class);
							var fsrl = FileSystemService.getInstance().getLocalFSRL(file);
							var folder = AppInfo.getActiveProject().getProjectData().getRootFolder();
							ImporterUtilities.showImportDialog(tool, manager, fsrl, folder, null);
							timer.cancel();
							return;
						}
					}
				}
			}
		}, 0, 100);
	}
}
EOF
javac -cp "$(find Ghidra.app -regex '.*\.jar' | tr '\n' ':')" OpenGhidraAgent.java
cat << EOF > manifest
Agent-Class: OpenGhidraAgent
EOF
jar --create --file OpenGhidra.jar --manifest manifest OpenGhidraAgent*.class
cp OpenGhidra.jar Ghidra.app/Contents/Resources