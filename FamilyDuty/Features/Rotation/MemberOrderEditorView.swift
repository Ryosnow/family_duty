import SwiftUI

struct MemberOrderEditorView: View {
    let members: [FamilyMember]
    @Binding var participantIDs: [UUID]

    var body: some View {
        List {
            ForEach(orderedMembers) { member in
                Label(member.name, systemImage: "line.3.horizontal")
            }
            .onMove { offsets, destination in
                participantIDs.move(fromOffsets: offsets, toOffset: destination)
            }
        }
        .navigationTitle("轮班顺序")
        .toolbar { EditButton() }
    }

    private var orderedMembers: [FamilyMember] {
        participantIDs.compactMap { id in members.first { $0.id == id } }
    }
}
