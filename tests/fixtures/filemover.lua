return {
    directories = {
        "target",
        "collision/directory",
        "source/directory/nested",
    },

    files = {
        ["source/file.txt"] = "file\n",
        ["source/directory/child.txt"] = "child\n",
        ["source/directory/nested/deep.txt"] = "deep\n",
        ["collision/directory/existing.txt"] = "collision\n",
    },

    symlinks = {
        ["source/link-to-file"] = "file.txt",
    },
}
