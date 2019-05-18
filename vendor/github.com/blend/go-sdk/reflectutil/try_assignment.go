package reflectutil

import "reflect"

func tryAssignment(field, value reflect.Value) (assigned bool, err error) {
	if value.Type().AssignableTo(field.Type()) {
		field.Set(value)
		assigned = true
		return
	}

	if value.Type().ConvertibleTo(field.Type()) {
		convertedValue := value.Convert(field.Type())
		if convertedValue.Type().AssignableTo(field.Type()) {
			field.Set(convertedValue)
			assigned = true
			return
		}
	}

	if field.Type().Kind() == reflect.Ptr {
		if value.Type().AssignableTo(field.Type().Elem()) {
			elem := reflect.New(field.Type().Elem())
			elem.Elem().Set(value)
			field.Set(elem)
			assigned = true
			return
		} else if value.Type().ConvertibleTo(field.Type().Elem()) {
			elem := reflect.New(field.Type().Elem())
			elem.Elem().Set(value.Convert(field.Type().Elem()))
			field.Set(elem)
			assigned = true
			return
		}
	}

	return
}
