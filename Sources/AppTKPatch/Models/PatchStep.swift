public protocol PatchStep {
    var name: String { get }
    func execute(context: inout IPAPatchContext) throws
}
