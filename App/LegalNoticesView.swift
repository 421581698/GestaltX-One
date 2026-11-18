import SwiftUI

struct LegalNoticesView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Open-source licenses") {
                    Text("GestaltX One links the GPL-3.0-only native DeviceConsole component from huamidev/GestaltX.")
                    Link("GNU General Public License v3.0", destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!)
                    Link("GestaltX upstream source", destination: URL(string: "https://github.com/huamidev/GestaltX")!)
                    Text("PairableHostAdvertiser also retains the Locus MIT attribution in its source header.")
                }

                Section("System permissions") {
                    Text("Pairing is started by an explicit action and completed through iOS Developer Mode and system confirmation. GestaltX One does not bypass device security, signing, or system permissions.")
                }

                Section("Current capability boundary") {
                    Text("Device pairing and protected local pairing-record storage are implemented in the native host. MobileGestalt direct read/write is not implemented. File import, preview, backup, and export are separate operations.")
                }

                Section("Source and notices") {
                    Text("The complete license and third-party notices are included in the GestaltX One source repository as LICENSE and NOTICE.md.")
                }
            }
            .navigationTitle("About & Licenses")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
