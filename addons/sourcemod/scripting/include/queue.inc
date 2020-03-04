#if defined _queue_included
 #endinput
#endif
#define _queue_included

#include <adt_array>

methodmap Queue < Handle {
	// Creates A FIFO Queue based on the behaviors of ArrayList and ArrayStack.
	// @param blocksize     The number of cells each member of the queue can
	//                      hold.
	// @return              New Handle to Queue object.
	public Queue(int blocksize = 1) {
		return view_as<Queue>(CreateArray(blocksize));
	}

	// Clones a queue, returning a new handle with the same size and data.
	// This should NOT be confused with CloneHandle. This is a completely new
	// handle with the same data but no relation to the original. It should
	// be closed when no longer needed.
	//
	// @return              New handle to the cloned queue object.
	public Queue Clone() {
		return view_as<Queue>(CloneArray(this));
	}

	// Pushes a value onto the end of the queue
	//
	// This may safely be used even if the queue has a blocksize greater
	// than 1
	//
	// @param value         Value to push.
	// @error               Invalid Handle or out of memory.
	public void Push(any value) {
		PushArrayCell(this, value);
	}

	// Pushes a string onto the end of the queue, truncating it if it is too big.
	//
	// @param value         String to push.
	public void PushString(const char[] value) {
		PushArrayString(this, value);
	}

	// Pushes an array of cells onto the end of the queue. The cells
	// are pushed as a block (i.e. the entire array sits at the index),
	// rather than pushing each cell individually
	//
	// @param values        Block of values to copy.
	// @param size          If not set, the number of elements copied from the array
	//                      will be equal to the blocksize.  If set higher than the
	//                      blocksize, the operation will be truncated.
	public void PushArray(const any[] values, int size = -1) {
		PushArrayArray(this, values, size);
	}

	// Retrieves and removes a cell value from the head of the queue
	//
	// @return               Value read.
	// @error                Invalid index (0).
	public any Pop() {
		any value = GetArrayCell(this, 0);
		RemoveFromArray(this, 0);
		return value;
	}

	// Retrieves and removes a string value from the head of the queue
	//
	// @param buffer        Buffer to copy to.
	// @param maxlength     Maximum size of the buffer.
	// @return              Number of characters copied.
	// @error               Invalid index (0).
	public int PopString(char[] buffer, int maxlength) {
		int charCount = GetArrayString(this, 0, buffer, maxlength);
		RemoveFromArray(this, 0);
		return charCount;
	}

	// Retrieves and removes an array value from the head of the queue
	//
	// @param buffer        Buffer to store the array in.
	// @param size          If not set, assumes the buffer size is equal to the
	//                      blocksize.  Otherwise, the size passed is used.
	// @return              Number of cells copied.
	// @error               Invalid index.
	public int PopArray(any[] buffer, int size = -1) {
		int cellCount = GetArrayArray(this, 0, buffer, size);
		RemoveFromArray(this, 0);
		return cellCount;
	}

	// Returns true if the queue is empty, false otherwise.
	property bool Empty {
		public get() { return !GetArraySize(this); }
	}

	// Returns length of the queue
	property int Length {
		public get() { return GetArraySize(this); }
	}

	// Returns the blocksize the queue was created with.
	property int BlockSize {
		public get() { return GetArrayBlockSize(this); }
	}
}
