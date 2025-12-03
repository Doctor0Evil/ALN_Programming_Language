fun acceptProjectIfCompliant(project: Project, allChecks: List<ComplianceCheck>): Boolean {
    val passed = allChecks.all { it.passed }
    if (passed) {
        EthicsProtectionRegistry.registerProject(project.copy(compliancePassed = true))
        EthicsProtectionRegistry.logAudit("Project ${project.name} validated and secured under compliance protocols.")
        return true
    } else {
        EthicsProtectionRegistry.logAudit("Project ${project.name} rejected - compliance check(s) failed.")
        return false
    }
}
