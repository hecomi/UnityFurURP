using UnityEngine;

namespace Fur.Example
{

public class MoveAndRotateObject : MonoBehaviour
{
    [SerializeField] float speed = 180;
    [SerializeField] Vector3 scale = Vector3.one;
    private float angle_ = 0f;
    private Vector3 axis_;
    private Vector3 center_;

    void Start()
    {
        axis_ = Random.insideUnitSphere;
        center_ = transform.position;
    }

    void Update()
    {
        angle_ += speed * Time.deltaTime;
        transform.rotation = Quaternion.AngleAxis(angle_, axis_);
        transform.position = center_ + new Vector3(
            scale.x * Mathf.Sin(Time.time * Mathf.PI * 0.5f),
            scale.y * Mathf.Cos(Time.time * Mathf.PI * 0.2f),
            scale.z * Mathf.Cos(Time.time * Mathf.PI * 0.3f));
    }
}

}
