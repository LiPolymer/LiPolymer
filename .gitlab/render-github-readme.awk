# Converts the primary GitLab README.md into the GitHub profile README.md.
# Fails with exit code 1 if any expected sync marker block is missing or malformed.

BEGIN {
    in_banner = 0
    in_badges = 0
    in_stats = 0
    seen_banner = 0
    seen_badges = 0
    seen_stats = 0
    had_error = 0
}

{
    sub(/\r$/, "")
}

$0 == "<!-- sync:banner-start -->" {
    if (in_banner || in_badges || in_stats) {
        print "Error: nested sync:banner-start" > "/dev/stderr"
        had_error = 1
        exit 1
    }
    in_banner = 1
    seen_banner++
    print "![Header Light](./assets/banner_compact_light.svg#gh-light-mode-only)"
    print "![Header Dark](./assets/banner_compact_dark.svg#gh-dark-mode-only)"
    next
}

$0 == "<!-- sync:banner-end -->" {
    if (!in_banner) {
        print "Error: unexpected sync:banner-end" > "/dev/stderr"
        had_error = 1
        exit 1
    }
    in_banner = 0
    next
}

in_banner { next }

$0 == "<!-- sync:badges-start -->" {
    if (in_banner || in_badges || in_stats) {
        print "Error: nested sync:badges-start" > "/dev/stderr"
        had_error = 1
        exit 1
    }
    in_badges = 1
    seen_badges++
    next
}

$0 == "<!-- sync:badges-end -->" {
    if (!in_badges) {
        print "Error: unexpected sync:badges-end" > "/dev/stderr"
        had_error = 1
        exit 1
    }
    in_badges = 0
    next
}

in_badges {
    if (index($0, "api.visitorbadge.io/api/visitors") > 0) {
        gsub(/https%3A%2F%2Fgitlab\.com%2FLiPolymer/, "https%3A%2F%2Fgithub.com%2FLiPolymer%2FLiPolymer%2F")
        print $0
        next
    }
    if (index($0, "Find_me_on-GitHub") > 0) {
        print "[![GitLab](https://img.shields.io/badge/Find_me_on-GitLab-FF8C00?style=flat-square&logo=gitlab&logoColor=white)](https://gitlab.com/LiPolymer)"
        next
    }
    print $0
    next
}

$0 == "<!-- sync:stats-title-start -->" {
    if (in_banner || in_badges || in_stats) {
        print "Error: nested sync:stats-title-start" > "/dev/stderr"
        had_error = 1
        exit 1
    }
    in_stats = 1
    seen_stats++
    print "### 📈 Stats"
    next
}

$0 == "<!-- sync:stats-title-end -->" {
    if (!in_stats) {
        print "Error: unexpected sync:stats-title-end" > "/dev/stderr"
        had_error = 1
        exit 1
    }
    in_stats = 0
    next
}

in_stats { next }

{ print $0 }

END {
    if (had_error) {
        exit 1
    }
    if (in_banner || in_badges || in_stats) {
        print "Error: unclosed sync block in README.md" > "/dev/stderr"
        exit 1
    }
    if (seen_banner != 1 || seen_badges != 1 || seen_stats != 1) {
        print "Error: expected exactly 1 banner, badges, and stats-title block" > "/dev/stderr"
        exit 1
    }
}
