"""Focused, isolated Godot import verification for the static female art sample."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'blender-assets/samples/female-light-armour-v01'
GD='''extends SceneTree
func _initialize() -> void:
    call_deferred("verify")
func verify() -> void:
    var packed := load("res://character.glb") as PackedScene
    assert(packed != null, "Static GLB must import as a scene")
    var model := packed.instantiate()
    root.add_child(model)
    var queue: Array[Node] = [model]
    var names: Array[String] = []
    var surfaces := 0
    var triangles := 0
    var skeletons := 0
    while not queue.is_empty():
        var node: Node = queue.pop_front()
        if node is MeshInstance3D:
            assert(node.mesh != null and node.mesh.get_surface_count() > 0)
            names.append(str(node.name))
            surfaces += node.mesh.get_surface_count()
            triangles += int(node.mesh.get_faces().size() / 3)
            node.visible = false
            assert(not node.visible)
            node.visible = true
        if node is Skeleton3D:
            skeletons += 1
        for child in node.get_children():
            queue.append(child)
    assert(names.size() == 6, "Six separately removable static modules required")
    assert(triangles > 1000 and skeletons == 0, "This delivery is a static art study")
    var report := {
        "godot": Engine.get_version_info().string,
        "checks": "PASS", "mesh_modules": names,
        "material_surfaces": surfaces, "triangles": triangles,
        "skeletons": skeletons, "animation_ready": false,
        "rendered_in_godot": false, "runtime_performance": "NOT_MEASURED"
    }
    var file := FileAccess.open("res://verification.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "  "))
    file.close()
    print("GODOT_STATIC_FEMALE_OK " + JSON.stringify(report))
    model.queue_free()
    quit(0)
'''


def main():
    p=argparse.ArgumentParser();p.add_argument('--godot',required=True);args=p.parse_args()
    temp_base=Path(tempfile.gettempdir()).resolve()
    work=Path(tempfile.mkdtemp(prefix='rts-female-static-',dir=temp_base)).resolve()
    assert work.parent==temp_base and work.name.startswith('rts-female-static-')
    logs=[]
    try:
        source=OUT/'female-light-armour-static.glb'
        shutil.copy2(source,work/'character.glb')
        (work/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Female static art import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
        (work/'verify.gd').write_text(GD,encoding='utf-8')
        for options in [['--editor','--import'],['--script','res://verify.gd']]:
            run=subprocess.run([args.godot,'--headless','--path',str(work),*options],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
            logs.append(run.stdout+'\n'+run.stderr)
            if run.returncode or 'SCRIPT ERROR' in run.stderr or 'ERROR:' in run.stderr:
                raise RuntimeError(logs[-1])
        report=json.loads((work/'verification.json').read_text(encoding='utf-8'))
        report['glb_sha256']=hashlib.sha256(source.read_bytes()).hexdigest()
        (OUT/'godot-import-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        build=json.loads((OUT/'build-report.json').read_text(encoding='utf-8'))
        build['godot_import']=report['checks']
        build['godot_verification_report']='godot-import-report.json'
        (OUT/'build-report.json').write_text(json.dumps(build,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(report,indent=2))
    finally:
        (OUT/'godot-import.log').write_text('\n'.join(logs).rstrip()+'\n',encoding='utf-8')
        assert work.parent==temp_base and work.name.startswith('rts-female-static-')
        shutil.rmtree(work)


if __name__=='__main__':main()
