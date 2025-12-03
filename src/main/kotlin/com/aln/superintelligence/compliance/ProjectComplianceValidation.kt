data class Project(
    val id: String, val name: String, val description: String, val owner: String, val compliancePassed: Boolean
)
data class ComplianceCheck(
    val id: String, val projectId: String, val type: String, val passed: Boolean, val checkedBy: String, val checkedOn: String
)
data class SafetyProtocol(
    val id: String, val name: String, val type: String, val description: String, val hash: String
)

object EthicsProtectionRegistry {
    private val projects = mutableSetOf<Project>()
    private val checks = mutableSetOf<ComplianceCheck>()
    private val protocols = mutableSetOf<SafetyProtocol>()
    private val auditTrail = mutableListOf<String>()

    fun registerProject(project: Project) {
        if (project.compliancePassed) {
            projects.add(project)
            VoiceFeedbackSystem.speak("Project registered and passes compliance: ${project.name}")
        }
    }
    fun addComplianceCheck(check: ComplianceCheck) {
        if (check.passed) checks.add(check)
    }
    fun addSafetyProtocol(protocol: SafetyProtocol) = protocols.add(protocol)
    fun logAudit(event: String) = auditTrail.add("[${java.time.Instant.now()}] $event")
    fun getSafeProjects() = projects.toSet()
}
