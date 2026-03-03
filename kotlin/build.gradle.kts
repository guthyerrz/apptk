plugins { kotlin("jvm") version "2.0.21" }
group = "com.apptk"
repositories { mavenCentral() }

tasks.jar {
    archiveBaseName.set("apptk-kotlin")
    from(configurations.runtimeClasspath.get().map { if (it.isDirectory) it else zipTree(it) })
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
}
