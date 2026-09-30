# New Repo Checklist

Create a brand-new empty GitHub repository.

Recommended name:
`HealthyMe-Beta`

When creating it:
- Public or private: your choice
- Do NOT initialize with README
- Do NOT add .gitignore
- Do NOT add a license

Then extract this package into the cloned repository.

For the first CI build, the workflow can temporarily generate the Android platform shell if `android/`
has not been committed yet.

For the proper long-term layout:
1. Run `scripts/bootstrap_android.sh` on the Linux development laptop.
2. Commit the generated `android/` folder.
3. After that, remove the temporary CI bootstrap step from `build_android.yml`.
4. Configure a permanent beta signing key through GitHub Actions secrets before distributing updateable release APKs.
