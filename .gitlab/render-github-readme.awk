# Converts the primary GitLab README.md into the GitHub profile README.md.
# Fails with exit code 1 if any expected sync marker block is missing or malformed.

function AnyBlockOpen() {
    return InBanner || InBadges || InProjects || InStatsTitle || InStats
}

function FailWith(Msg) {
    print "Error: " Msg > "/dev/stderr"
    HadError = 1
    exit 1
}

function PrintStatsPicture(AltText, ApiUrl, IncludeRing,    DarkUrl, LightUrl) {
    DarkUrl = ApiUrl "&theme=transparent&hide_border=true&title_color=86D6BE&icon_color=86D6BE&text_color=C9D1D9"
    LightUrl = ApiUrl "&theme=transparent&hide_border=true&title_color=0F6B57&icon_color=0F6B57&text_color=294B5E"
    if (IncludeRing) {
        DarkUrl = DarkUrl "&ring_color=86D6BE"
        LightUrl = LightUrl "&ring_color=0F6B57"
    }
    print "  <picture>"
    print "    <source media=\"(prefers-color-scheme: dark)\" srcset=\"" DarkUrl "\" />"
    print "    <source media=\"(prefers-color-scheme: light)\" srcset=\"" LightUrl "\" />"
    print "    <img src=\"" LightUrl "\" height=\"165\" alt=\"" AltText "\" />"
    print "  </picture>"
}

BEGIN {
    InBanner = 0
    InBadges = 0
    InProjects = 0
    InStatsTitle = 0
    InStats = 0
    SeenBanner = 0
    SeenBadges = 0
    SeenProjects = 0
    SeenStatsTitle = 0
    SeenStats = 0
    HadError = 0
}

{
    sub(/\r$/, "")
}

$0 == "<!-- sync:banner-start -->" {
    if (AnyBlockOpen()) FailWith("nested sync:banner-start")
    InBanner = 1
    SeenBanner++
    print "<p align=\"center\">"
    print "  <picture>"
    print "    <source media=\"(prefers-color-scheme: dark)\" srcset=\"./assets/banner_compact_dark.svg\" />"
    print "    <source media=\"(prefers-color-scheme: light)\" srcset=\"./assets/banner_compact_light.svg\" />"
    print "    <img src=\"./assets/banner_compact_light.svg\" alt=\"LiPolymer — Let Innovation Happen.\" />"
    print "  </picture>"
    print "</p>"
    next
}

$0 == "<!-- sync:banner-end -->" {
    if (!InBanner) FailWith("unexpected sync:banner-end")
    InBanner = 0
    next
}

InBanner { next }

$0 == "<!-- sync:badges-start -->" {
    if (AnyBlockOpen()) FailWith("nested sync:badges-start")
    InBadges = 1
    SeenBadges++
    next
}

$0 == "<!-- sync:badges-end -->" {
    if (!InBadges) FailWith("unexpected sync:badges-end")
    InBadges = 0
    next
}

InBadges {
    if (index($0, "api.visitorbadge.io/api/visitors") > 0) {
        gsub(/https%3A%2F%2Fgitlab\.com%2FLiPolymer/, "https%3A%2F%2Fgithub.com%2FLiPolymer%2FLiPolymer%2F")
        print $0
        next
    }
    if (index($0, "Find_me_on-GitHub") > 0) {
        print "  <a href=\"https://gitlab.com/LiPolymer\"><img src=\"https://img.shields.io/badge/Find_me_on-GitLab-0F6B57?style=flat-square&logo=gitlab&logoColor=white&labelColor=294B5E\" alt=\"GitLab\" /></a>"
        next
    }
    print $0
    next
}

$0 == "<!-- sync:projects-start -->" {
    if (AnyBlockOpen()) FailWith("nested sync:projects-start")
    InProjects = 1
    SeenProjects++
    next
}

$0 == "<!-- sync:projects-end -->" {
    if (!InProjects) FailWith("unexpected sync:projects-end")
    InProjects = 0
    next
}

InProjects {
    gsub(/https:\/\/gitlab\.com\/LiPolymer\/ExtraIsland/, "https://github.com/LiPolymer/ExtraIsland")
    print $0
    next
}

$0 == "<!-- sync:stats-title-start -->" {
    if (AnyBlockOpen()) FailWith("nested sync:stats-title-start")
    InStatsTitle = 1
    SeenStatsTitle++
    print "### 📈 Stats"
    next
}

$0 == "<!-- sync:stats-title-end -->" {
    if (!InStatsTitle) FailWith("unexpected sync:stats-title-end")
    InStatsTitle = 0
    next
}

InStatsTitle { next }

$0 == "<!-- sync:stats-start -->" {
    if (AnyBlockOpen()) FailWith("nested sync:stats-start")
    InStats = 1
    SeenStats++
    print "<p align=\"center\">"
    PrintStatsPicture("GitHub Stats", "https://github-stats-extended.vercel.app/api?username=LiPolymer&show_icons=true", 1)
    PrintStatsPicture("Top Languages", "https://github-stats-extended.vercel.app/api/top-langs/?username=LiPolymer&layout=compact&langs_count=8&hide=typescript,dockerfile,c,xslt,mdx", 0)
    print "</p>"
    next
}

$0 == "<!-- sync:stats-end -->" {
    if (!InStats) FailWith("unexpected sync:stats-end")
    InStats = 0
    next
}

InStats { next }

{ print $0 }

END {
    if (HadError) {
        exit 1
    }
    if (AnyBlockOpen()) {
        print "Error: unclosed sync block in README.md" > "/dev/stderr"
        exit 1
    }
    if (SeenBanner != 1 || SeenBadges != 1 || SeenProjects != 1 || SeenStatsTitle != 1 || SeenStats != 1) {
        print "Error: expected exactly 1 banner, badges, projects, stats-title, and stats block" > "/dev/stderr"
        exit 1
    }
}

