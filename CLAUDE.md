# Project Notes

## Build Workflow

- 每次编码完成后，自动执行打包构建（正式包），无需等用户指示。
- 构建流程：clean build → 从 `build/Build/Products/Release/` 打包 .app 到 `release/图片整理.zip` → 最后 `rm -rf build/Build/Products/Release` 清理残留旧包。
