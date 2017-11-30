using UnityEngine;

public class FlyCamera : MonoBehaviour
{
	public float minSpeed = 0.5f;
	public float mainSpeed = 10f; // Regular speed.
	public float shiftMultiplier = 2f;  // Multiplied by how long shift is held.  Basically running.
	public float camMouseSens = .35f;  // Camera sensitivity by mouse input.
	public float camJoyStickSens = 100f;  // Camera sensitivity by mouse input.
	private Vector3 lastMouse = new Vector3(Screen.width / 2, Screen.height / 2, 0); // Kind of in the middle of the screen, rather than at the top (play).

	public bool clickToMove = true;

	void Update()
	{
		//ProcessJoystick();
		ProcessMouse();
	}

	void ProcessJoystick()
	{
		transform.Rotate(Vector3.right, -Input.GetAxis("RightAnalog_Vertical") * Time.unscaledDeltaTime * camJoyStickSens, Space.Self);
		transform.Rotate(Vector3.up, Input.GetAxis("RightAnalog_Horizontal") * Time.unscaledDeltaTime * camJoyStickSens, Space.World);

		mainSpeed += (Input.GetAxis("10th Joystick Axis") - Input.GetAxis("9th Joystick Axis")) * mainSpeed * 2f * Time.unscaledDeltaTime;
		if (mainSpeed < minSpeed)
			mainSpeed = minSpeed;

		float translateX = Input.GetAxis("LeftAnalog_Horizontal") * mainSpeed * Time.unscaledDeltaTime;
		float translateZ = -Input.GetAxis("LeftAnalog_Vertical") * mainSpeed * Time.unscaledDeltaTime;

		transform.Translate(new Vector3(translateX, 0, translateZ));
	}

	void ProcessMouse()
	{
		if (clickToMove)
		{
			if (!Input.GetMouseButton(0))
				return;

			if (Input.GetMouseButtonDown(0))
			{
				lastMouse = Input.mousePosition;
				return;
			}
		}

		mainSpeed += Input.GetAxis("Mouse ScrollWheel") * mainSpeed * 2f;
		if (mainSpeed < minSpeed)
			mainSpeed = minSpeed;

		// Mouse input.
		lastMouse = Input.mousePosition - lastMouse;
		lastMouse = new Vector3(-lastMouse.y * camMouseSens, lastMouse.x * camMouseSens, 0);
		lastMouse = new Vector3(transform.eulerAngles.x + lastMouse.x, transform.eulerAngles.y + lastMouse.y, 0);
		transform.eulerAngles = lastMouse;
		lastMouse = Input.mousePosition;

		// Keyboard commands.
		Vector3 p = getDirection();

		if (Input.GetKey(KeyCode.LeftShift))
			p = p * mainSpeed * shiftMultiplier;
		else
			p = p * mainSpeed;

		p = p * Time.unscaledDeltaTime;
		
		transform.Translate(p);
	}

	private Vector3 getDirection()
	{
		Vector3 p_Velocity = new Vector3();
		if (Input.GetKey(KeyCode.W))
		{
			p_Velocity += new Vector3(0, 0, 1);
		}
		if (Input.GetKey(KeyCode.S))
		{
			p_Velocity += new Vector3(0, 0, -1);
		}
		if (Input.GetKey(KeyCode.A))
		{
			p_Velocity += new Vector3(-1, 0, 0);
		}
		if (Input.GetKey(KeyCode.D))
		{
			p_Velocity += new Vector3(1, 0, 0);
		}
		if (Input.GetKey(KeyCode.R))
		{
			p_Velocity += new Vector3(0, 1, 0);
		}
		if (Input.GetKey(KeyCode.F))
		{
			p_Velocity += new Vector3(0, -1, 0);
		}
		return p_Velocity;
	}

	public void resetRotation(Vector3 lookAt)
	{
		transform.LookAt(lookAt);
	}
}