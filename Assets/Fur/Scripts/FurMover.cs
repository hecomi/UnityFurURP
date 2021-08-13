using UnityEngine;

namespace Fur
{

[RequireComponent(typeof(Renderer))]
public class FurMover : MonoBehaviour
{
    ComputeBuffer _buffer = null;

    void OnEnable()
    {
        int numVertices = 0;

        var meshFilter = GetComponent<MeshFilter>();
        if (meshFilter)
        {
            numVertices = meshFilter.sharedMesh.vertexCount;
        }

        var skinnedMeshRenderer = GetComponent<SkinnedMeshRenderer>();
        if (skinnedMeshRenderer)
        {
            numVertices = skinnedMeshRenderer.sharedMesh.vertexCount;
        }

        if (numVertices == 0) return;

        var renderer = GetComponent<Renderer>();
        if (!renderer) return;

        _buffer = new ComputeBuffer(numVertices * 2, 12 * 3 + 4);
        Graphics.SetRandomWriteTarget(1, _buffer, true);

        foreach (var mat in renderer.materials)
        {
            mat.SetBuffer("_Buffer", _buffer);
        }
    }

    void OnDisable()
    {
        if (_buffer == null) return;

        _buffer.Dispose();
        _buffer = null;
    }
}

}
