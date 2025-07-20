# Awesome Cv Action

<img src="https://user-images.githubusercontent.com/4768226/210252649-ff3d1461-58e5-4670-9d50-be3f947e2216.png" width="100%" />

> A GitHub action to keep you Awesome CV up to date through continuous integration

## 🏆 How this action can help you ?

If you are an automation lover you will realize that one of the pain we need to automate is our resume...

By using a manual process we need to go through old versions, find the right one, update, reshape etc...

Nowaday a few open source project help to support that pain from an edition perspective such as : [Awesome-CV](https://github.com/posquit0/Awesome-CV) from [posquit0](https://github.com/posquit0) (based in Latex).

**This how i came up with the idea of automating the resume exactly like a software!**

A simple pipeline supports 6 steps for you:

1. **Validate** your LaTeX files with chktex to catch common errors
2. **Process** all include files from `resume/` directory and create a consolidated `.tex` artifact
3. **Compile** your resume into a .pdf
4. **Create** a git tag and a github release
5. **Upload** both the resume PDF and the .tex artifact to the github release
6. **Access** your files from anywhere through simple URLs like:
   - PDF: [YOUR RESUME REPO URL]/releases/download/latest/resume.pdf
   - TEX: [YOUR RESUME REPO URL]/releases/download/latest/resume_artifact.tex

## 🚀 Usage


First you will need to have add the action to a repository forked from [Awesome-CV](https://github.com/posquit0/Awesome-CV) 

If your resume filename is `john-doe.tex`, run it like this:

### Creates 2 tags (latest and v[VYYDDMM.HH.MM])

This allowing to have an extra tag named `latest` allowing the use the same url to access your resume from anywhere (portfolio, linkedin, email, etc)

```yaml
name: Awesome-CI

on: [push]

jobs:
  awesome-cv-job:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v1
    - uses: p4c4t/awesome-cv-action@latest
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        FILE_NAME: 'john-doe.tex'

```

### Creates 1 tags (v[YYDDMM.HH.MM])

```yaml
name: Awesome-CV-CI

on: [push]

jobs:
  awesome-cv-job:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v1
    - uses: p4c4t/awesome-cv-action@latest
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        FILE_NAME: 'john-doe.tex'
        LATEST_TAG: 'false' # set to false if you don't want an auto tag of latest (default: true)

```

## ✨ Enhanced Features

### LaTeX Validation with chktex
The action now includes automatic LaTeX validation using `chktex` before compilation. This helps catch common LaTeX errors and style issues early in the process. If chktex validation fails, the action will stop and report the errors.

### Resume Includes Processing
If your repository contains a `resume/` directory with `.tex` include files, the action will:
- Process all `.tex` files in the `resume/` directory
- Create a consolidated `.tex` artifact that contains your main resume plus all includes
- Upload both the compiled PDF and the consolidated `.tex` artifact to GitHub releases

This is particularly useful for:
- Modular resume organization (separate files for skills, experience, projects, etc.)
- Creating backup copies of your complete resume in a single file
- Sharing the complete LaTeX source along with the PDF

### Example Directory Structure
```
your-resume-repo/
├── john-doe.tex          # Main resume file
├── resume/               # Optional includes directory
│   ├── skills.tex        # Skills section
│   ├── experience.tex    # Experience section
│   └── projects.tex      # Projects section
└── .github/
    └── workflows/
        └── resume.yml    # GitHub Action workflow
```

## 👨‍💻  Multi-Resume

If you would like get all the chance in on your side while you apply for a job you might want to create different resume!
Then with this action is very easy :) all you need is to create a new branch. And then everytime you will commit a change a new tag will be created.


## 🎄 Credits

This action is based on the original work by [Olivier Rodomond](https://github.com/olivierodo). The pipeline automation concept was initially developed using Github apps and Heroku with https://latexonline.cc, but this GitHub Action version provides a much simpler setup.

### ⭐️ References

* [Awesome-CV](https://github.com/posquit0/Awesome-CV) - The original LaTeX template by posquit0
* [Original Action](https://github.com/olivierodo/awesome-cv-action) - Created by Olivier Rodomond

