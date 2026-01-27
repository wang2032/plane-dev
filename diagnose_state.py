#!/usr/bin/env python
"""
Plane 状态删除诊断工具
用于检查为什么某个状态无法删除
"""
import os
import sys
import django

# 设置 Django 环境
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'apps', 'api'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'plane.settings.production')
django.setup()

from plane.db.models import State, Issue, Project
from django.db.models import Count


def diagnose_state(state_name=None, state_id=None, project_id=None):
    """诊断状态无法删除的原因"""

    print("=" * 60)
    print("🔍 Plane 状态删除诊断工具")
    print("=" * 60)
    print()

    # 查找状态
    try:
        if state_id:
            state = State.objects.get(id=state_id)
        elif state_name and project_id:
            state = State.objects.get(name=state_name, project_id=project_id)
        else:
            print("❌ 请提供 state_id 或 (state_name + project_id)")
            print("\n使用方法:")
            print("  python diagnose_state.py --state-id <STATE_ID>")
            print("  python diagnose_state.py --state-name <NAME> --project-id <PROJECT_ID>")
            return

        print(f"✅ 找到状态: {state.name}")
        print(f"   ID: {state.id}")
        print(f"   项目 ID: {state.project_id}")
        print()

    except State.DoesNotExist:
        print(f"❌ 未找到指定的状态")
        return

    # 检查状态属性
    print("📋 状态属性:")
    print(f"   名称: {state.name}")
    print(f"   描述: {state.description or '无'}")
    print(f"   是否为默认状态: {'❌ 是' if state.default else '✅ 否'}")
    print(f"   是否为 Triage 状态: {'❌ 是' if state.is_triage else '✅ 否'}")
    print(f"   所属组: {state.group}")
    print(f"   颜色: {state.color}")
    print(f"   创建时间: {state.created_at}")
    print(f"   是否已删除: {'是' if state.deleted_at else '否'}")
    print()

    # 检查关联的任务
    print("📊 关联任务统计:")

    # 使用 Issue.objects 管理器（与删除检查相同的查询）
    issues = Issue.objects.filter(state=state)

    # 总数（与删除检查一致）
    total_count = issues.count()

    # 按状态细分
    active_issues = issues.filter(archived_at__isnull=True, is_draft=False)
    archived_issues = issues.filter(archived_at__isnull=False)
    draft_issues = issues.filter(is_draft=True)

    print(f"   总任务数: {total_count}")
    print(f"   - 活跃任务: {active_issues.count()}")
    print(f"   - 已归档任务: {archived_issues.count()}")
    print(f"   - 草稿任务: {draft_issues.count()}")
    print()

    # 显示最近的任务
    if total_count > 0:
        print("📝 最近的关联任务:")
        for issue in active_issues[:5]:
            print(f"   - #{issue.identifier} {issue.name}")
            print(f"     创建者: {issue.created_by}")
            print(f"     状态: {issue.state.name}")
        print()

    # 诊断能否删除
    print("=" * 60)
    print("🔬 诊断结果:")
    print("=" * 60)

    can_delete = True
    reasons = []

    # 检查 1: 默认状态
    if state.default:
        can_delete = False
        reasons.append("❌ 这是默认状态（default=True）")
        print()
        print("⚠️  问题 1: 这是默认状态")
        print("   解决方案:")
        print("   1. 先将其他状态设置为默认状态")
        print("   2. 然后再删除此状态")

    # 检查 2: Triage 状态
    if state.is_triage:
        can_delete = False
        reasons.append("❌ 这是 Triage 状态（is_triage=True）")
        print()
        print("⚠️  问题 2: 这是 Triage 状态")
        print("   Triage 状态不能通过 API 删除")

    # 检查 3: 有关联任务
    if total_count > 0:
        can_delete = False
        reasons.append(f"❌ 有 {total_count} 个关联任务")
        print()
        print("⚠️  问题 3: 该状态下还有任务")
        print(f"   总共 {total_count} 个任务与该状态关联")
        print()
        print("   解决方案:")
        print("   1. 将所有任务移动到其他状态")
        print("   2. 或在数据库中强制删除任务（不推荐）")

    # 检查 4: 是否唯一状态
    state_group_count = State.objects.filter(
        project_id=state.project_id,
        group=state.group,
        deleted_at__isnull=True
    ).count()

    if state_group_count == 1:
        can_delete = False
        reasons.append("❌ 这是该组中唯一的状态")
        print()
        print("⚠️  问题 4: 这是该组中唯一的状态")
        print(f"   '{state.group}' 组只有这一个状态")
        print()
        print("   解决方案:")
        print("   1. 先在该组中创建新状态")
        print("   2. 或将此状态移动到其他组")

    print()
    print("=" * 60)

    if can_delete:
        print("✅ 该状态可以删除")
        print()
        print("如果仍然无法删除，可能是以下原因:")
        print("   1. 权限不足（需要管理员或成员角色）")
        print("   2. 前端缓存问题（尝试刷新页面或清除缓存）")
        print("   3. 浏览器控制台有错误信息（请检查控制台）")
    else:
        print("❌ 该状态无法删除")
        print()
        print("阻塞原因:")
        for i, reason in enumerate(reasons, 1):
            print(f"   {i}. {reason}")

    print("=" * 60)
    print()

    # 提供修复建议
    if not can_delete:
        print("💡 建议的修复步骤:")
        print()

        if state.default:
            print("1. 设置其他状态为默认状态:")
            print("   - 进入项目设置 → 状态")
            print("   - 选择另一个状态并设置为默认")
            print()

        if total_count > 0:
            print("2. 批量移动任务:")
            print("   - 进入该状态视图")
            print("   - 全选所有任务（Ctrl/Cmd + A）")
            print("   - 批量更改状态到其他状态")
            print()

        if state_group_count == 1:
            print("3. 创建新状态或合并:")
            print("   - 在该组中创建新状态")
            print("   - 或考虑将状态移动到其他组")
            print()

        print("4. 完成上述步骤后，再次尝试删除状态")

    return can_delete


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='诊断 Plane 状态无法删除的问题')
    parser.add_argument('--state-id', help='状态的 ID')
    parser.add_argument('--state-name', help='状态的名称')
    parser.add_argument('--project-id', help='项目的 ID')

    args = parser.parse_args()

    diagnose_state(
        state_id=args.state_id,
        state_name=args.state_name,
        project_id=args.project_id
    )
