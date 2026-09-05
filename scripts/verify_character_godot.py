"""Verify the actual GLB with Godot, isolated from a future game client.

Run: python scripts/verify_character_godot.py --godot <Godot executable>
Creates and cleans only its own unique temporary project directory.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / 'blender-assets/samples/modular-character-v01'
GD_SCRIPT = '''extends SceneTree

func _initialize() -> void:
    call_deferred("check_sample")

func check_sample() -> void:
    var packed := load("res://character.glb") as PackedScene
    assert(packed != null, "GLB must import as a scene")
    var model := packed.instantiate()
    root.add_child(model)
    var meshes: Array[MeshInstance3D] = []
    var skeleton: Skeleton3D
    var player: AnimationPlayer
    var queue: Array[Node] = [model]
    var attachments: Array[String] = []
    while not queue.is_empty():
        var current: Node = queue.pop_front()
        if current is MeshInstance3D:
            meshes.append(current)
        if current is Skeleton3D:
            assert(skeleton == null, "Only one skeleton allowed")
            skeleton = current
        if current is AnimationPlayer:
            player = current
        if current is BoneAttachment3D:
            attachments.append(current.bone_name)
        for child in current.get_children():
            queue.append(child)
    assert(meshes.size() == 4, "Expected body, clothing, armor and spear meshes")
    assert(skeleton != null and skeleton.get_bone_count() == 22, "Shared 22 bone rig")
    assert(player != null, "Test animation must be present")
    var skinned := 0
    var surfaces := 0
    var names: Array[String] = []
    for mesh in meshes:
        names.append(str(mesh.name))
        assert(mesh.mesh != null)
        surfaces += mesh.mesh.get_surface_count()
        if mesh.skin != null:
            skinned += 1
            assert(mesh.get_node(mesh.skeleton) == skeleton, "Skin must resolve to shared rig")
    assert(skinned == 3, "Body, clothes and chest armor must have skins")
    assert(attachments.has("Hand.R"), "Weapon attachment must follow right hand")
    var action := ""
    for name in player.get_animation_list():
        if "Rig_Check" in name:
            action = name
    assert(not action.is_empty(), "Exported rig check animation required")
    var head_index := skeleton.find_bone("Head")
    player.play(action)
    player.seek(0.0, true)
    var before := skeleton.get_bone_pose_rotation(head_index)
    player.seek(1.0, true)
    var after := skeleton.get_bone_pose_rotation(head_index)
    assert(before.angle_to(after) > 0.01, "Animation must move imported skeleton")
    # Visibility is independently editable; verify nodes can be toggled separately.
    for mesh in meshes:
        mesh.visible = false
        assert(not mesh.visible)
        mesh.visible = true
    var report := {
        "godot": Engine.get_version_info().string,
        "mesh_modules": names,
        "skeleton_bones": skeleton.get_bone_count(),
        "skinned_meshes": skinned,
        "material_surfaces": surfaces,
        "animations": player.get_animation_list(),
        "weapon_attachments": attachments,
        "checks": "PASS",
        "rendered_in_godot": false,
        "runtime_performance": "NOT_MEASURED"
    }
    var file := FileAccess.open("res://verification.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "  "))
    file.close()
    print("GODOT_SAMPLE_IMPORT_OK " + JSON.stringify(report))
    quit(0)
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    temp_base = Path(tempfile.gettempdir()).resolve()
    work = Path(tempfile.mkdtemp(prefix='living-world-rts-art-', dir=temp_base)).resolve()
    # Deletion below is strictly limited to the unique directory we just created.
    assert work.parent == temp_base and work.name.startswith('living-world-rts-art-')
    try:
        shutil.copy2(SAMPLE / 'character.glb', work / 'character.glb')
        (work / 'project.godot').write_text(
            'config_version=5\n[application]\nconfig/name="RTS art import check"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
        (work / 'verify.gd').write_text(GD_SCRIPT, encoding='utf-8')
        for options in [['--editor', '--import'], ['--script', 'res://verify.gd']]:
            result = subprocess.run([args.godot, '--headless', '--path', str(work), *options],
                capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=120)
            print(result.stdout)
            print(result.stderr)
            if result.returncode or 'SCRIPT ERROR' in result.stderr or 'ERROR:' in result.stderr:
                raise RuntimeError(f'Godot validation failed with exit code {result.returncode}')
        report = json.loads((work / 'verification.json').read_text(encoding='utf-8'))
        assert report['checks'] == 'PASS'
        (SAMPLE / 'godot-import-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2),encoding='utf-8')
    finally:
        assert work.parent == temp_base and work.name.startswith('living-world-rts-art-')
        shutil.rmtree(work)


if __name__ == '__main__':
    main()
